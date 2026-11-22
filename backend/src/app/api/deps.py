import uuid
from collections.abc import Callable
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.permissions import (
    ROLE_HIERARCHY,
    has_required_role,
    role_has_permission,
)
from app.core.security import (
    TOKEN_TYPE_ACCESS,
    TokenExpiredError,
    TokenInvalidError,
    decode_token,
)
from app.db.session import get_db
from app.models.document import Document
from app.models.enums import Permission, RoleType
from app.models.issue import Issue
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.sprint import Sprint
from app.models.user import User
from app.models.workspace import Workspace

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
    auto_error=False,
)


def get_current_user(
    token: Annotated[str | None, Depends(oauth2_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    """
    Retrieve and validate the currently authenticated user from the Bearer token.

    :param token: JWT access token from Authorization header.
    :param db: Active database session.
    :return: Authenticated User entity.
    :raises HTTPException: 401 Unauthorized if token is missing, expired, invalid,
                           revoked, or if user does not exist or is inactive.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not token:
        raise credentials_exception

    try:
        payload = decode_token(
            token,
            expected_type=TOKEN_TYPE_ACCESS,
            check_revocation=True,
        )
    except TokenExpiredError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e
    except TokenInvalidError as e:
        raise credentials_exception from e

    sub = payload.get("sub")
    if not sub:
        raise credentials_exception

    try:
        user_id = uuid.UUID(sub)
    except ValueError as e:
        raise credentials_exception from e

    user = db.scalar(
        select(User).where(
            User.id == user_id,
            User.deleted_at.is_(None),
        )
    )

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Inactive user.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Convenience dependency returning the active authenticated user."""
    return current_user


def require_workspace_role(
    min_role: RoleType | str,
) -> Callable[..., WorkspaceMember]:
    """
    FastAPI dependency factory enforcing a minimum RoleType within a Workspace.

    Extracts `workspace_id` or `id` from route path parameters.
    - Returns 404 if workspace does not exist or user is not a member.
    - Returns 403 if user is a member but role level is below `min_role`.
    - Returns WorkspaceMember on success.
    """
    min_role_enum = min_role if isinstance(min_role, RoleType) else RoleType(min_role)

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> WorkspaceMember:
        raw_id = request.path_params.get("workspace_id") or request.path_params.get(
            "id"
        )
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        try:
            workspace_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        workspace = db.scalar(
            select(Workspace).where(
                Workspace.id == workspace_id,
                Workspace.deleted_at.is_(None),
            )
        )
        if workspace is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        member = db.scalar(
            select(WorkspaceMember).where(
                WorkspaceMember.workspace_id == workspace_id,
                WorkspaceMember.user_id == current_user.id,
            )
        )
        if member is None:
            # Users outside the workspace receive 404 to avoid leaking existence
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        if not has_required_role(member.role, min_role_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this workspace.",
            )

        return member

    return dependency


def require_workspace_permission(
    permission: Permission | str,
) -> Callable[..., WorkspaceMember]:
    """
    FastAPI dependency factory enforcing a specific Permission within a Workspace.

    - Returns 404 if workspace does not exist or user is not a member.
    - Returns 403 if user role lacks the required permission.
    - Returns WorkspaceMember on success.
    """
    perm_enum = (
        permission if isinstance(permission, Permission) else Permission(permission)
    )

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> WorkspaceMember:
        raw_id = request.path_params.get("workspace_id") or request.path_params.get(
            "id"
        )
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        try:
            workspace_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        workspace = db.scalar(
            select(Workspace).where(
                Workspace.id == workspace_id,
                Workspace.deleted_at.is_(None),
            )
        )
        if workspace is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        member = db.scalar(
            select(WorkspaceMember).where(
                WorkspaceMember.workspace_id == workspace_id,
                WorkspaceMember.user_id == current_user.id,
            )
        )
        if member is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workspace not found.",
            )

        if not role_has_permission(member.role, perm_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this workspace.",
            )

        return member

    return dependency


def require_project_role(
    min_role: RoleType | str,
) -> Callable[..., ProjectMember]:
    """
    FastAPI dependency factory enforcing a minimum RoleType within a Project.

    Extracts `project_id` or `id` from route path parameters.
    - Returns 404 if project does not exist or user is not a project/workspace member.
    - Returns 403 if user has insufficient role.
    - Grants workspace Owner/Admin access to projects in their workspace.
    - Returns ProjectMember on success.
    """
    min_role_enum = min_role if isinstance(min_role, RoleType) else RoleType(min_role)

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> ProjectMember:
        raw_id = request.path_params.get("project_id") or request.path_params.get("id")
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        try:
            project_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        project = db.scalar(
            select(Project).where(
                Project.id == project_id,
                Project.deleted_at.is_(None),
            )
        )
        if project is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        member = db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id == current_user.id,
            )
        )

        effective_role: RoleType | None = member.role if member else None

        # Check workspace membership for workspace Owner / Admin inheritance
        ws_member = db.scalar(
            select(WorkspaceMember).where(
                WorkspaceMember.workspace_id == project.workspace_id,
                WorkspaceMember.user_id == current_user.id,
            )
        )

        if (
            ws_member
            and ws_member.role in (RoleType.OWNER, RoleType.ADMIN)
            and (
                effective_role is None
                or ROLE_HIERARCHY.get(ws_member.role, 0)
                > ROLE_HIERARCHY.get(effective_role, 0)
            )
        ):
            effective_role = ws_member.role

        if effective_role is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        if not has_required_role(effective_role, min_role_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this project.",
            )

        if member is not None:
            return member

        return ProjectMember(
            project_id=project.id,
            user_id=current_user.id,
            role=effective_role,
        )

    return dependency


def require_project_permission(
    permission: Permission | str,
) -> Callable[..., ProjectMember]:
    """
    FastAPI dependency factory enforcing a specific Permission within a Project.

    - Returns 404 if project does not exist or user lacks access.
    - Returns 403 if user role lacks the required permission.
    - Returns ProjectMember on success.
    """
    perm_enum = (
        permission if isinstance(permission, Permission) else Permission(permission)
    )

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> ProjectMember:
        raw_id = request.path_params.get("project_id") or request.path_params.get("id")
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        try:
            project_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        project = db.scalar(
            select(Project).where(
                Project.id == project_id,
                Project.deleted_at.is_(None),
            )
        )
        if project is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        member = db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id == current_user.id,
            )
        )

        effective_role: RoleType | None = member.role if member else None

        ws_member = db.scalar(
            select(WorkspaceMember).where(
                WorkspaceMember.workspace_id == project.workspace_id,
                WorkspaceMember.user_id == current_user.id,
            )
        )

        if (
            ws_member
            and ws_member.role in (RoleType.OWNER, RoleType.ADMIN)
            and (
                effective_role is None
                or ROLE_HIERARCHY.get(ws_member.role, 0)
                > ROLE_HIERARCHY.get(effective_role, 0)
            )
        ):
            effective_role = ws_member.role

        if effective_role is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Project not found.",
            )

        if not role_has_permission(effective_role, perm_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this project.",
            )

        if member is not None:
            return member

        return ProjectMember(
            project_id=project.id,
            user_id=current_user.id,
            role=effective_role,
        )

    return dependency


def require_issue_permission(
    permission: Permission | str,
) -> Callable[..., Issue]:
    """
    FastAPI dependency factory enforcing a specific Permission within an Issue's Project.

    Extracts `issue_id` or `id` from route path parameters.
    - Returns 404 if issue does not exist or is soft-deleted, or user lacks access.
    - Returns 403 if user lacks required permission.
    - Returns active Issue on success.
    """
    perm_enum = (
        permission if isinstance(permission, Permission) else Permission(permission)
    )

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> Issue:
        raw_id = request.path_params.get("issue_id") or request.path_params.get("id")
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Issue not found.",
            )

        try:
            issue_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Issue not found.",
            )

        issue = db.scalar(
            select(Issue)
            .options(
                selectinload(Issue.parent),
                selectinload(Issue.sub_issues),
            )
            .where(
                Issue.id == issue_id,
                Issue.deleted_at.is_(None),
            )
        )
        if issue is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Issue not found.",
            )

        # Check project membership
        member = db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == issue.project_id,
                ProjectMember.user_id == current_user.id,
            )
        )
        effective_role: RoleType | None = member.role if member else None

        # Check workspace membership for workspace Owner / Admin inheritance
        project = db.scalar(
            select(Project).where(
                Project.id == issue.project_id,
                Project.deleted_at.is_(None),
            )
        )
        if project:
            ws_member = db.scalar(
                select(WorkspaceMember).where(
                    WorkspaceMember.workspace_id == project.workspace_id,
                    WorkspaceMember.user_id == current_user.id,
                )
            )
            if (
                ws_member
                and ws_member.role in (RoleType.OWNER, RoleType.ADMIN)
                and (
                    effective_role is None
                    or ROLE_HIERARCHY.get(ws_member.role, 0)
                    > ROLE_HIERARCHY.get(effective_role, 0)
                )
            ):
                effective_role = ws_member.role

        if effective_role is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Issue not found.",
            )

        if not role_has_permission(effective_role, perm_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this issue.",
            )

        return issue

    return dependency


def require_sprint_permission(
    permission: Permission | str,
) -> Callable[..., Sprint]:
    """
    FastAPI dependency factory enforcing a specific Permission within a Sprint's Project.

    Extracts `sprint_id` or `id` from route path parameters.
    - Returns 404 if sprint does not exist or is soft-deleted, or user lacks access.
    - Returns 403 if user lacks required permission.
    - Returns active Sprint on success.
    """
    perm_enum = (
        permission if isinstance(permission, Permission) else Permission(permission)
    )

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> Sprint:
        raw_id = request.path_params.get("sprint_id") or request.path_params.get("id")
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sprint not found.",
            )

        try:
            sprint_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sprint not found.",
            )

        sprint = db.scalar(
            select(Sprint).where(
                Sprint.id == sprint_id,
                Sprint.deleted_at.is_(None),
            )
        )
        if sprint is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sprint not found.",
            )

        # Check project membership
        member = db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == sprint.project_id,
                ProjectMember.user_id == current_user.id,
            )
        )
        effective_role: RoleType | None = member.role if member else None

        # Check workspace membership for workspace Owner / Admin inheritance
        project = db.scalar(
            select(Project).where(
                Project.id == sprint.project_id,
                Project.deleted_at.is_(None),
            )
        )
        if project:
            ws_member = db.scalar(
                select(WorkspaceMember).where(
                    WorkspaceMember.workspace_id == project.workspace_id,
                    WorkspaceMember.user_id == current_user.id,
                )
            )
            if (
                ws_member
                and ws_member.role in (RoleType.OWNER, RoleType.ADMIN)
                and (
                    effective_role is None
                    or ROLE_HIERARCHY.get(ws_member.role, 0)
                    > ROLE_HIERARCHY.get(effective_role, 0)
                )
            ):
                effective_role = ws_member.role

        if effective_role is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sprint not found.",
            )

        if not role_has_permission(effective_role, perm_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this sprint.",
            )

        return sprint

    return dependency


def require_document_permission(
    permission: Permission | str,
) -> Callable[..., Document]:
    """
    FastAPI dependency factory enforcing a specific Permission within a Document's Project.

    Extracts `document_id` or `id` from route path parameters.
    - Returns 404 if document does not exist or is soft-deleted, or user lacks access.
    - Returns 403 if user lacks required permission.
    - Returns active Document on success.
    """
    perm_enum = (
        permission if isinstance(permission, Permission) else Permission(permission)
    )

    def dependency(
        request: Request,
        current_user: Annotated[User, Depends(get_current_user)],
        db: Annotated[Session, Depends(get_db)],
    ) -> Document:
        raw_id = request.path_params.get("document_id") or request.path_params.get("id")
        if not raw_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Document not found.",
            )

        try:
            document_id = uuid.UUID(str(raw_id))
        except ValueError, AttributeError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Document not found.",
            )

        document = db.scalar(
            select(Document).where(
                Document.id == document_id,
                Document.deleted_at.is_(None),
            )
        )
        if document is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Document not found.",
            )

        member = db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == document.project_id,
                ProjectMember.user_id == current_user.id,
            )
        )
        effective_role: RoleType | None = member.role if member else None

        project = db.scalar(
            select(Project).where(
                Project.id == document.project_id,
                Project.deleted_at.is_(None),
            )
        )
        if project:
            ws_member = db.scalar(
                select(WorkspaceMember).where(
                    WorkspaceMember.workspace_id == project.workspace_id,
                    WorkspaceMember.user_id == current_user.id,
                )
            )
            if (
                ws_member
                and ws_member.role in (RoleType.OWNER, RoleType.ADMIN)
                and (
                    effective_role is None
                    or ROLE_HIERARCHY.get(ws_member.role, 0)
                    > ROLE_HIERARCHY.get(effective_role, 0)
                )
            ):
                effective_role = ws_member.role

        if effective_role is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Document not found.",
            )

        if not role_has_permission(effective_role, perm_enum):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this document.",
            )

        return document

    return dependency
