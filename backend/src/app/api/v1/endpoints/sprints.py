from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_sprint_permission
from app.db.session import get_db
from app.models.enums import Permission
from app.models.sprint import Sprint
from app.models.user import User
from app.schemas.sprint import SprintCreate, SprintResponse, SprintUpdate
from app.services.sprint import (
    create_sprint,
    delete_sprint,
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
