import enum


class RoleType(str, enum.Enum):
    """Member roles for Workspaces and Projects."""

    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"
    VIEWER = "viewer"


class Permission(str, enum.Enum):
    """Granular permissions governing operations across Oversee entities."""

    # Workspace permissions
    WORKSPACE_READ = "workspace:read"
    WORKSPACE_UPDATE = "workspace:update"
    WORKSPACE_DELETE = "workspace:delete"
    WORKSPACE_MANAGE_MEMBERS = "workspace:manage_members"

    # Project permissions
    PROJECT_CREATE = "project:create"
    PROJECT_READ = "project:read"
    PROJECT_UPDATE = "project:update"
    PROJECT_DELETE = "project:delete"
    PROJECT_MANAGE_MEMBERS = "project:manage_members"

    # Sprint permissions
    SPRINT_CREATE = "sprint:create"
    SPRINT_READ = "sprint:read"
    SPRINT_UPDATE = "sprint:update"
    SPRINT_DELETE = "sprint:delete"

    # Issue permissions
    ISSUE_CREATE = "issue:create"
    ISSUE_READ = "issue:read"
    ISSUE_UPDATE = "issue:update"
    ISSUE_DELETE = "issue:delete"
    ISSUE_COMMENT = "issue:comment"


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
