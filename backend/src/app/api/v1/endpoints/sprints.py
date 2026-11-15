import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_sprint_permission
from app.db.session import get_db
from app.models.enums import Permission
from app.models.sprint import Sprint
from app.models.user import User
from app.schemas.issue import IssueResponse
from app.schemas.sprint import (
    SprintAddIssuesRequest,
    SprintCreate,
    SprintPlanningResponse,
    SprintRemoveIssuesRequest,
    SprintResponse,
    SprintUpdate,
)
from app.services.sprint import (
    add_issues_to_sprint,
    create_sprint,
    delete_sprint,
    get_sprint_planning,
    list_sprint_issues,
    remove_issue_from_sprint,
    remove_issues_from_sprint,
    update_sprint,
)

router = APIRouter()


@router.post(
    "",
    response_model=SprintResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create sprint",
    description="Create a new sprint. Requires project_id in body and SPRINT_CREATE permission.",
)
def create_sprint_endpoint(
    data: SprintCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> SprintResponse:
    """Create a new sprint directly via the sprints router."""
    if data.project_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Field 'project_id' is required when creating a sprint.",
        )
    return create_sprint(
        db=db,
        project_id=data.project_id,
        actor=current_user,
        data=data,
    )


@router.get(
    "/{sprint_id}",
    response_model=SprintResponse,
    status_code=status.HTTP_200_OK,
    summary="Get sprint by ID",
    description="Retrieve details of a single sprint by ID. Requires SPRINT_READ permission.",
)
def get_sprint_endpoint(
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_READ))
    ],
) -> SprintResponse:
    """Retrieve details for a single sprint."""
    return sprint


@router.patch(
    "/{sprint_id}",
    response_model=SprintResponse,
    status_code=status.HTTP_200_OK,
    summary="Update sprint",
    description="Update sprint details (name, goal, dates, status). Requires SPRINT_UPDATE permission.",
)
def update_sprint_endpoint(
    data: SprintUpdate,
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> SprintResponse:
    """Update an existing sprint."""
    return update_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
        data=data,
    )


@router.delete(
    "/{sprint_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete sprint",
    description="Soft delete a sprint. Moves assigned issues back to backlog. Requires SPRINT_DELETE permission.",
)
def delete_sprint_endpoint(
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_DELETE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    """Soft delete a sprint and return assigned issues to backlog."""
    delete_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Sprint Planning & Issue Assignment Endpoints (#101)
# ---------------------------------------------------------------------------
@router.get(
    "/{sprint_id}/issues",
    response_model=list[IssueResponse],
    status_code=status.HTTP_200_OK,
    summary="List issues in sprint",
    description="Retrieve all issues assigned to this sprint. Requires SPRINT_READ permission.",
)
def list_sprint_issues_endpoint(
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> list[IssueResponse]:
    """List all issues currently assigned to the specified sprint."""
    return list_sprint_issues(db=db, sprint=sprint)


@router.post(
    "/{sprint_id}/issues",
    response_model=list[IssueResponse],
    status_code=status.HTTP_200_OK,
    summary="Assign issues to sprint",
    description="Assign one or more issues to this sprint. Requires SPRINT_UPDATE permission.",
)
def add_issues_to_sprint_endpoint(
    data: SprintAddIssuesRequest,
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[IssueResponse]:
    """Assign issues to sprint."""
    issue_ids = data.get_all_issue_ids()
    return add_issues_to_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
        issue_ids=issue_ids,
    )


@router.post(
    "/{sprint_id}/issues/{issue_id}",
    response_model=list[IssueResponse],
    status_code=status.HTTP_200_OK,
    summary="Assign single issue to sprint",
    description="Assign a single issue to this sprint. Requires SPRINT_UPDATE permission.",
)
def add_single_issue_to_sprint_endpoint(
    issue_id: uuid.UUID,
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[IssueResponse]:
    """Assign single issue to sprint."""
    return add_issues_to_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
        issue_ids=[issue_id],
    )


@router.delete(
    "/{sprint_id}/issues/{issue_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove issue from sprint",
    description="Remove an issue from this sprint and return it to the product backlog. Requires SPRINT_UPDATE permission.",
)
def remove_single_issue_from_sprint_endpoint(
    issue_id: uuid.UUID,
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    """Remove single issue from sprint, moving it back to backlog."""
    remove_issue_from_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
        issue_id=issue_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{sprint_id}/issues",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Batch remove issues from sprint",
    description="Remove multiple issues from this sprint and return them to the product backlog. Requires SPRINT_UPDATE permission.",
)
def remove_issues_from_sprint_endpoint(
    data: SprintRemoveIssuesRequest,
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    """Remove multiple issues from sprint."""
    issue_ids = data.get_all_issue_ids()
    remove_issues_from_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
        issue_ids=issue_ids,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{sprint_id}/issues/remove",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Batch remove issues from sprint (POST alias)",
    description="Remove multiple issues from this sprint and return them to the product backlog.",
)
def remove_issues_from_sprint_post_endpoint(
    data: SprintRemoveIssuesRequest,
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_UPDATE))
    ],
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    """Remove multiple issues from sprint (POST alias)."""
    issue_ids = data.get_all_issue_ids()
    remove_issues_from_sprint(
        db=db,
        sprint=sprint,
        actor=current_user,
        issue_ids=issue_ids,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/{sprint_id}/planning",
    response_model=SprintPlanningResponse,
    status_code=status.HTTP_200_OK,
    summary="Get sprint planning summary",
    description="Retrieve sprint planning metrics: assigned issues, total estimate, capacity limit, and warnings. Requires SPRINT_READ permission.",
)
def get_sprint_planning_endpoint(
    sprint: Annotated[
        Sprint, Depends(require_sprint_permission(Permission.SPRINT_READ))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> SprintPlanningResponse:
    """Get sprint planning summary metrics."""
    return get_sprint_planning(db=db, sprint=sprint)
