import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.permissions import role_has_permission
from app.models.document import Document
from app.models.enums import Permission
from app.models.project import Project
from app.models.user import User
from app.schemas.document import DocumentCreate, DocumentUpdate
from app.services.sprint import _resolve_effective_role


def create_document(
    db: Session,
    project_id: uuid.UUID,
    actor: User,
    data: DocumentCreate,
) -> Document:
    """Create a new document in a project after checking DOCUMENT_CREATE permission."""
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

    actor_role = _resolve_effective_role(db, project_id, actor.id)
    if actor_role is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found.",
        )
    if not role_has_permission(actor_role, Permission.DOCUMENT_CREATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to create documents in this project.",
        )

    doc = Document(
        project_id=project_id,
        title=data.title,
        content=data.content,
        author_id=actor.id,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)
    return doc


def list_project_documents(
    db: Session,
    project_id: uuid.UUID,
) -> list[Document]:
    """List all non-deleted documents for a project ordered by most recently updated."""
    stmt = (
        select(Document)
        .where(
            Document.project_id == project_id,
            Document.deleted_at.is_(None),
        )
        .order_by(Document.updated_at.desc(), Document.created_at.desc())
    )
    return list(db.scalars(stmt).all())


def update_document(
    db: Session,
    document: Document,
    data: DocumentUpdate,
) -> Document:
    """Update an existing document's title and/or content."""
    update_fields = data.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        setattr(document, field, value)

    db.add(document)
    db.commit()
    db.refresh(document)
    return document


def delete_document(
    db: Session,
    document: Document,
) -> None:
    """Soft delete a document."""
    document.soft_delete()
    db.add(document)
    db.commit()
