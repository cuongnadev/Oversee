import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_user,
    require_project_permission,
    require_project_role,
)
from app.db.session import get_db
from app.models.enums import IssueType, Permission, RoleType, SprintStatus
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.schemas.document import (
    DocumentCreate,
    DocumentResponse,
)
from app.schemas.issue import (
    BacklogAddIssuesRequest,
    BacklogOverviewResponse,
    BacklogReorderRequest,
    IssueCreate,
    IssuePageResponse,
    IssueResponse,
)
from app.schemas.membership import (
    ProjectMemberCreate,
    ProjectMemberResponse,
    ProjectMemberUpdate,
)
from app.schemas.project import (
    ProjectResponse,
    ProjectUpdate,
)
from app.schemas.sprint import (
    SprintCreate,
    SprintResponse,
)
from app.services.document import (
    create_document,
    list_project_documents,
)
from app.services.issue import (
    add_issues_to_backlog,
    create_issue,
    get_backlog_overview,
    list_backlog_issues,
    list_project_issues,
    parse_issue_priorities,
    parse_issue_statuses,
    remove_issue_from_backlog,
    reorder_backlog_issue,
)
from app.services.project import (
    add_project_member,
    archive_project,
    get_project_by_id,
    list_project_members,
    remove_project_member,
    restore_project,
    update_project,
    update_project_member_role,
)
from app.services.sprint import (
    create_sprint,
    list_project_sprints,
)

router = APIRouter()


# ---------------------------------------------------------------------------
# Project CRUD Endpoints (#90)
# ---------------------------------------------------------------------------
@router.get(
    "/{project_id}",
    response_model=ProjectResponse,
    status_code=status.HTTP_200_OK,
    summary="Get project by ID",
    description="Retrieve details for a project. Requires project membership or workspace admin access.",
)
def get_project(
    project_id: uuid.UUID,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.VIEWER))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Retrieve details of a single project."""
    return get_project_by_id(db=db, project_id=project_id)


@router.patch(
    "/{project_id}",
    response_model=ProjectResponse,
    status_code=status.HTTP_200_OK,
    summary="Update project",
    description="Update project details (name, key, description). Requires ADMIN role or higher.",
)
def update_existing_project(
    project_id: uuid.UUID,
    data: ProjectUpdate,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Update project details."""
    project = get_project_by_id(db=db, project_id=project_id)
    return update_project(db=db, project=project, data=data)


@router.delete(
    "/{project_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Archive (soft delete) project",
    description="Soft delete (archive) a project. Requires ADMIN role or higher.",
)
def archive_existing_project(
    project_id: uuid.UUID,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Archive a project."""
    project = get_project_by_id(db=db, project_id=project_id)
    archive_project(db=db, project=project)


@router.post(
    "/{project_id}/restore",
    response_model=ProjectResponse,
    status_code=status.HTTP_200_OK,
    summary="Restore archived project",
    description="Restore a soft-deleted (archived) project. Requires workspace ADMIN role or higher.",
)
def restore_archived_project(
    project_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Restore an archived project."""
    project = db.scalar(select(Project).where(Project.id == project_id))
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found.",
        )

    # Check workspace admin permissions
    ws_member = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == project.workspace_id,
            WorkspaceMember.user_id == current_user.id,
        )
    )
    if not ws_member or ws_member.role not in (RoleType.OWNER, RoleType.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to restore project.",
        )

    return restore_project(db=db, project=project)


# ---------------------------------------------------------------------------
# Project Member Management Endpoints (#91)
# ---------------------------------------------------------------------------
@router.get(
    "/{project_id}/members",
    response_model=list[ProjectMemberResponse],
    status_code=status.HTTP_200_OK,
    summary="List project members",
    description="List all members in the specified project. Requires project VIEWER role or higher.",
)
def get_project_members(
    project_id: uuid.UUID,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.VIEWER))],
    db: Annotated[Session, Depends(get_db)],
) -> list[ProjectMemberResponse]:
    """Retrieve all members of the project."""
    return list_project_members(db=db, project_id=project_id)


@router.post(
    "/{project_id}/members",
    response_model=ProjectMemberResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add member to project",
    description=(
        "Add an existing workspace user to the project with the specified role. "
        "User must already belong to the parent workspace. Requires project ADMIN role or higher."
    ),
)
def add_member_to_project(
    project_id: uuid.UUID,
    data: ProjectMemberCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectMemberResponse:
    """Add a member to the project."""
    return add_project_member(
        db=db,
        actor=current_user,
        project_id=project_id,
        data=data,
    )


@router.patch(
    "/{project_id}/members/{user_id}",
    response_model=ProjectMemberResponse,
    status_code=status.HTTP_200_OK,
    summary="Update project member role",
    description=(
        "Update the role of a project member. Requires project ADMIN role or higher. "
        "ADMIN cannot modify an OWNER role. Cannot demote the last project OWNER."
    ),
)
def update_member_role_in_project(
    project_id: uuid.UUID,
    user_id: uuid.UUID,
    data: ProjectMemberUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectMemberResponse:
    """Update role for an existing project member."""
    return update_project_member_role(
        db=db,
        actor=current_user,
        project_id=project_id,
        target_user_id=user_id,
        data=data,
    )


@router.delete(
    "/{project_id}/members/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove project member",
    description=(
        "Remove a member from the project, or leave the project (self-removal). "
        "Requires ADMIN role to remove others. Cannot remove the last project OWNER."
    ),
)
def remove_member_from_project(
    project_id: uuid.UUID,
    user_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.VIEWER))],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Remove a member or self-leave from the project."""
    remove_project_member(
        db=db,
        actor=current_user,
        project_id=project_id,
        target_user_id=user_id,
    )


# ---------------------------------------------------------------------------
# Project Issue Endpoints (#94)
# ---------------------------------------------------------------------------
@router.post(
    "/{project_id}/issues",
    response_model=IssueResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create issue in project",
    description="Create a new issue/task in the project. Requires ISSUE_CREATE permission (MEMBER or higher).",
)
def create_project_issue(
    project_id: uuid.UUID,
    data: IssueCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_CREATE))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> IssueResponse:
    """Create a new issue in the project."""
    return create_issue(
        db=db,
        actor=current_user,
        project_id=project_id,
        data=data,
    )


@router.get(
    "/{project_id}/issues",
    response_model=IssuePageResponse,
    status_code=status.HTTP_200_OK,
    summary="List project issues",
    description="List all non-deleted issues in the project with filtering, sorting, and pagination. Requires ISSUE_READ permission (VIEWER or higher).",
)
def list_project_issues_endpoint(
    project_id: uuid.UUID,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
    page: int = Query(1, ge=1, description="Page number starting from 1"),
    page_size: int = Query(
        20, ge=1, le=100, description="Number of items per page (max 100)"
    ),
    status_filter: Annotated[
        list[str] | None,
        Query(
            alias="status",
            description="Filter by issue status (repeatable or comma-separated, e.g. 'todo,in_progress')",
        ),
    ] = None,
    assignee_id: Annotated[
        uuid.UUID | None,
        Query(description="Filter by assignee user ID"),
    ] = None,
    assignee: Annotated[
        str | None,
        Query(description="Filter by assignee ('unassigned' or user UUID string)"),
    ] = None,
    priority: Annotated[
        list[str] | None,
        Query(
            description="Filter by priority (repeatable or comma-separated, e.g. 'high,urgent')"
        ),
    ] = None,
    sprint_id: Annotated[
        uuid.UUID | None,
        Query(description="Filter by sprint ID"),
    ] = None,
    sprint: Annotated[
        str | None,
        Query(description="Filter by sprint ('none', 'backlog', or sprint UUID)"),
    ] = None,
    type: Annotated[
        IssueType | None,
        Query(description="Filter by issue type (e.g. 'task', 'bug', 'story')"),
    ] = None,
    parent_id: Annotated[
        uuid.UUID | None,
        Query(description="Filter by parent issue ID"),
    ] = None,
    search: Annotated[
        str | None,
        Query(description="Search keyword in title or description"),
    ] = None,
    sort: Annotated[
        str | None,
        Query(
            description="Multi-field sort expression, e.g. 'priority:desc,created_at:asc' or '-priority,created_at'"
        ),
    ] = None,
    sort_by: Annotated[
        str | None,
        Query(description="Field name to sort by"),
    ] = None,
    order: Annotated[
        str,
        Query(description="Sort direction ('asc' or 'desc')"),
    ] = "asc",
    cursor: Annotated[
        str | None,
        Query(description="Cursor for cursor-based pagination"),
    ] = None,
) -> IssuePageResponse:
    """List issues in the project with filtering, multi-field sorting, and pagination."""
    parsed_statuses = parse_issue_statuses(status_filter)
    parsed_priorities = parse_issue_priorities(priority)

    return list_project_issues(
        db=db,
        project_id=project_id,
        page=page,
        page_size=page_size,
        statuses=parsed_statuses,
        assignee_id=assignee_id,
        assignee=assignee,
        priorities=parsed_priorities,
        sprint_id=sprint_id,
        sprint=sprint,
        issue_type=type,
        parent_id=parent_id,
        search=search,
        sort=sort,
        sort_by=sort_by,
        order=order,
        cursor=cursor,
    )


# ---------------------------------------------------------------------------
# Product Backlog Endpoints (#98)
# ---------------------------------------------------------------------------
@router.get(
    "/{project_id}/backlog",
    response_model=IssuePageResponse,
    status_code=status.HTTP_200_OK,
    summary="List product backlog issues",
    description="List active issues in the project's product backlog (unassigned to any sprint). Requires ISSUE_READ permission.",
)
def list_backlog_endpoint(
    project_id: uuid.UUID,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
    page: int = Query(1, ge=1, description="Page number starting from 1"),
    page_size: int = Query(
        20, ge=1, le=100, description="Number of items per page (max 100)"
    ),
    status_filter: Annotated[
        list[str] | None,
        Query(
            alias="status",
            description="Filter by issue status (repeatable or comma-separated)",
        ),
    ] = None,
    assignee_id: Annotated[
        uuid.UUID | None,
        Query(description="Filter by assignee user ID"),
    ] = None,
    assignee: Annotated[
        str | None,
        Query(description="Filter by assignee ('unassigned' or user UUID string)"),
    ] = None,
    priority: Annotated[
        list[str] | None,
        Query(description="Filter by priority (repeatable or comma-separated)"),
    ] = None,
    type: Annotated[
        IssueType | None,
        Query(description="Filter by issue type"),
    ] = None,
    parent_id: Annotated[
        uuid.UUID | None,
        Query(description="Filter by parent issue ID"),
    ] = None,
    search: Annotated[
        str | None,
        Query(description="Search keyword in title or description"),
    ] = None,
    sort: Annotated[
        str | None,
        Query(
            description="Sort expression (defaults to 'backlog_rank:asc,issue_number:asc')"
        ),
    ] = None,
    sort_by: Annotated[
        str | None,
        Query(description="Field name to sort by"),
    ] = None,
    order: Annotated[
        str,
        Query(description="Sort direction ('asc' or 'desc')"),
    ] = "asc",
    cursor: Annotated[
        str | None,
        Query(description="Cursor for cursor-based pagination"),
    ] = None,
) -> IssuePageResponse:
    """Retrieve backlog issues for the project."""
    parsed_statuses = parse_issue_statuses(status_filter)
    parsed_priorities = parse_issue_priorities(priority)

    return list_backlog_issues(
        db=db,
        project_id=project_id,
        page=page,
        page_size=page_size,
        statuses=parsed_statuses,
        assignee_id=assignee_id,
        assignee=assignee,
        priorities=parsed_priorities,
        issue_type=type,
        parent_id=parent_id,
        search=search,
        sort=sort,
        sort_by=sort_by,
        order=order,
        cursor=cursor,
    )


@router.get(
    "/{project_id}/backlog/grouped",
    response_model=BacklogOverviewResponse,
    status_code=status.HTTP_200_OK,
    summary="List backlog and sprint issues grouped by sprint",
    description=(
        "Return all active project issues grouped by sprint (with completion counts and story points) "
        "plus unassigned product backlog issues. Requires ISSUE_READ permission."
    ),
)
def get_grouped_backlog_endpoint(
    project_id: uuid.UUID,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
    status_filter: Annotated[
        list[str] | None,
        Query(alias="status", description="Filter by issue status"),
    ] = None,
    assignee_id: Annotated[
        uuid.UUID | None,
        Query(description="Filter by assignee user ID"),
    ] = None,
    assignee: Annotated[
        str | None,
        Query(description="Filter by assignee ('unassigned' or user UUID string)"),
    ] = None,
    priority: Annotated[
        list[str] | None,
        Query(description="Filter by priority"),
    ] = None,
    type: Annotated[
        IssueType | None,
        Query(description="Filter by issue type"),
    ] = None,
    search: Annotated[
        str | None,
        Query(description="Search keyword in title or description"),
    ] = None,
) -> BacklogOverviewResponse:
    """Retrieve issues grouped by sprint plus unassigned backlog."""
    parsed_statuses = parse_issue_statuses(status_filter)
    parsed_priorities = parse_issue_priorities(priority)
    return get_backlog_overview(
        db=db,
        project_id=project_id,
        statuses=parsed_statuses,
        assignee_id=assignee_id,
        assignee=assignee,
        priorities=parsed_priorities,
        issue_type=type,
        search=search,
    )


@router.post(
    "/{project_id}/backlog/issues",
    response_model=list[IssueResponse],
    status_code=status.HTTP_200_OK,
    summary="Add issues to product backlog",
    description="Move one or more existing project issues into the product backlog. Requires ISSUE_UPDATE permission.",
)
def add_to_backlog_endpoint(
    project_id: uuid.UUID,
    data: BacklogAddIssuesRequest,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[IssueResponse]:
    """Move issues to backlog."""
    return add_issues_to_backlog(
        db=db,
        project_id=project_id,
        actor=current_user,
        issue_ids=data.get_all_issue_ids(),
    )


@router.delete(
    "/{project_id}/backlog/issues/{issue_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove issue from product backlog",
    description="Remove an issue from the product backlog (soft delete, or move to sprint if target_sprint_id is specified).",
)
def remove_from_backlog_endpoint(
    project_id: uuid.UUID,
    issue_id: uuid.UUID,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_READ))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    target_sprint_id: Annotated[
        uuid.UUID | None,
        Query(
            description="Optional target sprint ID to move issue to instead of deleting"
        ),
    ] = None,
) -> Response:
    """Remove issue from product backlog."""
    remove_issue_from_backlog(
        db=db,
        project_id=project_id,
        issue_id=issue_id,
        actor=current_user,
        target_sprint_id=target_sprint_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch(
    "/{project_id}/backlog/reorder",
    response_model=IssueResponse,
    status_code=status.HTTP_200_OK,
    summary="Reorder issue in product backlog",
    description="Move an issue before, after, or between other backlog issues. Requires ISSUE_UPDATE permission.",
)
def reorder_backlog_endpoint(
    project_id: uuid.UUID,
    data: BacklogReorderRequest,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.ISSUE_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> IssueResponse:
    """Reorder a backlog issue."""
    return reorder_backlog_issue(
        db=db,
        project_id=project_id,
        issue_id=data.issue_id,
        actor=current_user,
        previous_issue_id=data.previous_issue_id,
        next_issue_id=data.next_issue_id,
        target_rank=data.target_rank,
        position=data.position,
    )


# ---------------------------------------------------------------------------
# Sprint Endpoints (#100)
# ---------------------------------------------------------------------------
@router.post(
    "/{project_id}/sprints",
    response_model=SprintResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create sprint for project",
    description="Create a new sprint under a project. Requires SPRINT_CREATE permission.",
)
def create_project_sprint_endpoint(
    project_id: uuid.UUID,
    data: SprintCreate,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.SPRINT_CREATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> SprintResponse:
    """Create a new sprint for a project."""
    return create_sprint(
        db=db,
        project_id=project_id,
        actor=current_user,
        data=data,
    )


@router.get(
    "/{project_id}/sprints",
    response_model=list[SprintResponse],
    status_code=status.HTTP_200_OK,
    summary="List sprints for project",
    description="Retrieve all non-deleted sprints for a project. Filterable by status. Requires SPRINT_READ permission.",
)
def list_project_sprints_endpoint(
    project_id: uuid.UUID,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.SPRINT_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
    status_filter: Annotated[
        SprintStatus | None,
        Query(alias="status", description="Filter sprints by status"),
    ] = None,
) -> list[SprintResponse]:
    """Retrieve all sprints for a project."""
    return list_project_sprints(
        db=db,
        project_id=project_id,
        status_filter=status_filter,
    )


# ---------------------------------------------------------------------------
# Document Endpoints (#181)
# ---------------------------------------------------------------------------
@router.post(
    "/{project_id}/documents",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create document in project",
    description="Create a new document under a project. Requires DOCUMENT_CREATE permission.",
)
def create_project_document_endpoint(
    project_id: uuid.UUID,
    data: DocumentCreate,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.DOCUMENT_CREATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> DocumentResponse:
    """Create a new document in a project."""
    return create_document(
        db=db,
        project_id=project_id,
        actor=current_user,
        data=data,
    )


@router.get(
    "/{project_id}/documents",
    response_model=list[DocumentResponse],
    status_code=status.HTTP_200_OK,
    summary="List documents for project",
    description="Retrieve all non-deleted documents for a project ordered by updated_at desc. Requires DOCUMENT_READ permission.",
)
def list_project_documents_endpoint(
    project_id: uuid.UUID,
    member: Annotated[
        ProjectMember, Depends(require_project_permission(Permission.DOCUMENT_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> list[DocumentResponse]:
    """Retrieve all documents for a project."""
    return list_project_documents(db=db, project_id=project_id)
