import enum


class RoleType(str, enum.Enum):
    """Member roles for Workspaces and Projects."""

    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"
    VIEWER = "viewer"


class IssueType(str, enum.Enum):
    """Categorization types for Issues."""

    EPIC = "epic"
    STORY = "story"
    TASK = "task"
    BUG = "bug"
    SUBTASK = "subtask"


class IssueStatus(str, enum.Enum):
    """Workflow progress states for Issues."""

    BACKLOG = "backlog"
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    IN_REVIEW = "in_review"
    DONE = "done"
    CANCELED = "canceled"


class IssuePriority(str, enum.Enum):
    """Priority levels for Issues."""

    LOWEST = "lowest"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


class SprintStatus(str, enum.Enum):
    """Lifecycle states for Sprints."""

    PLANNED = "planned"
    ACTIVE = "active"
    COMPLETED = "completed"
    CLOSED = "closed"
