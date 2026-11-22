from app.core.permissions import (
    ROLE_HIERARCHY,
    ROLE_PERMISSIONS,
    Permission,
    get_role_permissions,
    has_required_role,
    role_has_permission,
)
from app.models.enums import RoleType


# ---------------------------------------------------------------------------
# 1. Permission Enum & Hierarchy Tests
# ---------------------------------------------------------------------------
def test_permission_enum_values_and_prefixes():
    """Verify all permissions have non-empty unique values with proper namespace prefixes."""
    perm_values = [p.value for p in Permission]
    assert len(perm_values) == len(set(perm_values))

    valid_prefixes = ("workspace:", "project:", "sprint:", "issue:", "document:")
    for perm in Permission:
        assert perm.value.startswith(valid_prefixes)


def test_role_hierarchy_ordering():
    """Verify that VIEWER < MEMBER < ADMIN < OWNER strictly holds."""
    assert ROLE_HIERARCHY[RoleType.VIEWER] == 1
    assert ROLE_HIERARCHY[RoleType.MEMBER] == 2
    assert ROLE_HIERARCHY[RoleType.ADMIN] == 3
    assert ROLE_HIERARCHY[RoleType.OWNER] == 4


def test_has_required_role_evaluation():
    """Verify role hierarchy evaluations for all combinations."""
    # OWNER satisfies all roles
    assert has_required_role(RoleType.OWNER, RoleType.OWNER) is True
    assert has_required_role(RoleType.OWNER, RoleType.ADMIN) is True
    assert has_required_role(RoleType.OWNER, RoleType.MEMBER) is True
    assert has_required_role(RoleType.OWNER, RoleType.VIEWER) is True

    # ADMIN satisfies ADMIN, MEMBER, VIEWER, but not OWNER
    assert has_required_role(RoleType.ADMIN, RoleType.OWNER) is False
    assert has_required_role(RoleType.ADMIN, RoleType.ADMIN) is True
    assert has_required_role(RoleType.ADMIN, RoleType.MEMBER) is True
    assert has_required_role(RoleType.ADMIN, RoleType.VIEWER) is True

    # MEMBER satisfies MEMBER, VIEWER, but not ADMIN or OWNER
    assert has_required_role(RoleType.MEMBER, RoleType.OWNER) is False
    assert has_required_role(RoleType.MEMBER, RoleType.ADMIN) is False
    assert has_required_role(RoleType.MEMBER, RoleType.MEMBER) is True
    assert has_required_role(RoleType.MEMBER, RoleType.VIEWER) is True

    # VIEWER satisfies only VIEWER
    assert has_required_role(RoleType.VIEWER, RoleType.OWNER) is False
    assert has_required_role(RoleType.VIEWER, RoleType.ADMIN) is False
    assert has_required_role(RoleType.VIEWER, RoleType.MEMBER) is False
    assert has_required_role(RoleType.VIEWER, RoleType.VIEWER) is True


def test_has_required_role_accepts_strings_and_handles_invalid():
    """Verify has_required_role accepts valid string inputs and safely handles invalid."""
    assert has_required_role("owner", "admin") is True
    assert has_required_role("member", "viewer") is True
    assert has_required_role("viewer", "admin") is False
    assert has_required_role("invalid_role", "viewer") is False
    assert has_required_role("admin", "invalid_role") is False


# ---------------------------------------------------------------------------
# 2. Role-Permission Matrix Tests
# ---------------------------------------------------------------------------
def test_viewer_role_permissions():
    """Verify VIEWER has strictly read-only permissions across all resources."""
    viewer_perms = ROLE_PERMISSIONS[RoleType.VIEWER]
    assert viewer_perms == frozenset(
        {
            Permission.WORKSPACE_READ,
            Permission.PROJECT_READ,
            Permission.SPRINT_READ,
            Permission.ISSUE_READ,
            Permission.DOCUMENT_READ,
        }
    )
    assert Permission.WORKSPACE_UPDATE not in viewer_perms
    assert Permission.ISSUE_CREATE not in viewer_perms
    assert Permission.SPRINT_CREATE not in viewer_perms
    assert Permission.DOCUMENT_CREATE not in viewer_perms


def test_member_role_permissions():
    """Verify MEMBER has read permissions + sprint/issue creation and update."""
    member_perms = ROLE_PERMISSIONS[RoleType.MEMBER]

    # Includes all viewer permissions
    assert ROLE_PERMISSIONS[RoleType.VIEWER].issubset(member_perms)

    # Has collaboration permissions
    assert Permission.ISSUE_CREATE in member_perms
    assert Permission.ISSUE_UPDATE in member_perms
    assert Permission.ISSUE_COMMENT in member_perms
    assert Permission.SPRINT_CREATE in member_perms
    assert Permission.SPRINT_UPDATE in member_perms

    # Does NOT have administrative permissions
    assert Permission.WORKSPACE_UPDATE not in member_perms
    assert Permission.WORKSPACE_DELETE not in member_perms
    assert Permission.WORKSPACE_MANAGE_MEMBERS not in member_perms
    assert Permission.PROJECT_CREATE not in member_perms
    assert Permission.PROJECT_DELETE not in member_perms
    assert Permission.SPRINT_DELETE not in member_perms
    assert Permission.ISSUE_DELETE not in member_perms


def test_admin_role_permissions():
    """Verify ADMIN has project/workspace management but not workspace:delete."""
    admin_perms = ROLE_PERMISSIONS[RoleType.ADMIN]

    # Includes all member permissions
    assert ROLE_PERMISSIONS[RoleType.MEMBER].issubset(admin_perms)

    # Has admin management permissions
    assert Permission.WORKSPACE_UPDATE in admin_perms
    assert Permission.WORKSPACE_MANAGE_MEMBERS in admin_perms
    assert Permission.PROJECT_CREATE in admin_perms
    assert Permission.PROJECT_UPDATE in admin_perms
    assert Permission.PROJECT_DELETE in admin_perms
    assert Permission.PROJECT_MANAGE_MEMBERS in admin_perms
    assert Permission.SPRINT_DELETE in admin_perms
    assert Permission.ISSUE_DELETE in admin_perms

    # Only OWNER can delete workspace
    assert Permission.WORKSPACE_DELETE not in admin_perms


def test_owner_role_permissions():
    """Verify OWNER has every permission defined in Permission enum."""
    owner_perms = ROLE_PERMISSIONS[RoleType.OWNER]
    assert owner_perms == frozenset(Permission)
    assert Permission.WORKSPACE_DELETE in owner_perms


# ---------------------------------------------------------------------------
# 3. Helper Functions Tests
# ---------------------------------------------------------------------------
def test_role_has_permission_helper():
    """Verify role_has_permission works with enums, strings, and invalid inputs."""
    assert role_has_permission(RoleType.OWNER, Permission.WORKSPACE_DELETE) is True
    assert role_has_permission(RoleType.ADMIN, Permission.WORKSPACE_DELETE) is False
    assert role_has_permission("member", "issue:create") is True
    assert role_has_permission("viewer", "issue:create") is False

    # Invalid inputs
    assert role_has_permission("non_existent_role", "issue:create") is False
    assert role_has_permission(RoleType.MEMBER, "non_existent_perm") is False


def test_get_role_permissions_helper():
    """Verify get_role_permissions returns correct frozen set or empty for invalid."""
    perms = get_role_permissions(RoleType.VIEWER)
    assert isinstance(perms, frozenset)
    assert Permission.WORKSPACE_READ in perms

    # String input
    assert get_role_permissions("owner") == frozenset(Permission)

    # Invalid input
    assert get_role_permissions("unknown") == frozenset()
