from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_document_permission
from app.db.session import get_db
from app.models.document import Document
from app.models.enums import Permission
from app.models.user import User
from app.schemas.document import DocumentCreate, DocumentResponse, DocumentUpdate
from app.services.document import create_document, delete_document, update_document

router = APIRouter()


@router.post(
    "",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create document",
    description="Create a new project document. Requires project_id in body and DOCUMENT_CREATE permission.",
)
def create_document_endpoint(
    data: DocumentCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> DocumentResponse:
    """Create a new document directly via the documents router."""
    if data.project_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Field 'project_id' is required when creating a document.",
        )
    return create_document(
        db=db,
        project_id=data.project_id,
        actor=current_user,
        data=data,
    )


@router.get(
    "/{document_id}",
    response_model=DocumentResponse,
    status_code=status.HTTP_200_OK,
    summary="Get document by ID",
    description="Retrieve a single document by ID. Requires DOCUMENT_READ permission.",
)
def get_document_endpoint(
    document: Annotated[
        Document, Depends(require_document_permission(Permission.DOCUMENT_READ))
    ],
) -> DocumentResponse:
    """Retrieve a single document."""
    return document


@router.patch(
    "/{document_id}",
    response_model=DocumentResponse,
    status_code=status.HTTP_200_OK,
    summary="Update document",
    description="Update document title or content. Requires DOCUMENT_UPDATE permission.",
)
def update_document_endpoint(
    data: DocumentUpdate,
    document: Annotated[
        Document, Depends(require_document_permission(Permission.DOCUMENT_UPDATE))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> DocumentResponse:
    """Update an existing document."""
    return update_document(db=db, document=document, data=data)


@router.delete(
    "/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete document",
    description="Soft delete a document. Requires DOCUMENT_DELETE permission.",
)
def delete_document_endpoint(
    document: Annotated[
        Document, Depends(require_document_permission(Permission.DOCUMENT_DELETE))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    """Soft delete a document."""
    delete_document(db=db, document=document)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
