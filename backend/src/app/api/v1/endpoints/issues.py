import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_issue_permission
from app.db.session import get_db
from app.models.enums import Permission
from app.models.issue import Issue
from app.models.user import User
from app.schemas.issue import IssueCreate, IssueResponse, IssueUpdate
from app.services.issue import (
    create_issue,
    delete_issue,
    list_sub_issues,
    restore_issue,
    update_issue,
)

router = APIRouter()


@router.post(
    "",
    response_model=IssueResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create issue",
    description="Create a new issue/task. Requires project_id in body and ISSUE_CREATE permission in that project.",
)
def create_issue_endpoint(
    data: IssueCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> IssueResponse:
    """Create a new issue directly via the issues router."""
    if data.project_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Field 'project_id' is required when creating an issue.",
        )
    return create_issue(
        db=db,
        actor=current_user,
        project_id=data.project_id,
        data=data,
    )


@router.get(
    "/{issue_id}",
    response_model=IssueResponse,
    status_code=status.HTTP_200_OK,
    summary="Get issue by ID",
    description="Retrieve details of a single issue. Requires project membership or workspace admin access.",
)
def get_issue(
    issue: Annotated[Issue, Depends(require_issue_permission(Permission.ISSUE_READ))],
) -> IssueResponse:
    """Retrieve details of an active issue."""
    return issue


@router.patch(
    "/{issue_id}",
    response_model=IssueResponse,
    status_code=status.HTTP_200_OK,
    summary="Update issue",
    description="Update issue attributes. Requires ISSUE_UPDATE permission (MEMBER or higher).",
)
def update_issue_endpoint(
    data: IssueUpdate,
    issue: Annotated[Issue, Depends(require_issue_permission(Permission.ISSUE_UPDATE))],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> IssueResponse:
    """Update attributes of an existing issue."""
    return update_issue(
        db=db,
        issue=issue,
        actor=current_user,
        data=data,
    )


@router.delete(
    "/{issue_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete (archive) issue",
    description="Soft delete an issue and its active sub-issues. Requires ISSUE_DELETE permission (ADMIN or higher).",
)
def delete_issue_endpoint(
    issue: Annotated[Issue, Depends(require_issue_permission(Permission.ISSUE_DELETE))],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Soft delete an issue."""
    delete_issue(db=db, issue=issue)


@router.post(
    "/{issue_id}/restore",
    response_model=IssueResponse,
    status_code=status.HTTP_200_OK,
    summary="Restore deleted issue",
    description="Restore a soft-deleted issue and its sub-issues. Requires ISSUE_DELETE permission (ADMIN or higher).",
)
def restore_issue_endpoint(
    issue_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> IssueResponse:
    """Restore a soft-deleted issue."""
    return restore_issue(db=db, issue_id=issue_id, actor=current_user)


@router.get(
    "/{issue_id}/sub-issues",
    response_model=list[IssueResponse],
    status_code=status.HTTP_200_OK,
    summary="List sub-issues",
    description="Retrieve all active child issues for a parent issue. Requires ISSUE_READ permission.",
)
def get_sub_issues(
    issue: Annotated[Issue, Depends(require_issue_permission(Permission.ISSUE_READ))],
    db: Annotated[Session, Depends(get_db)],
) -> list[IssueResponse]:
    """Retrieve child issues of the specified parent issue."""
    return list_sub_issues(db=db, issue_id=issue.id)
