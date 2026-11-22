from typing import Final

from app.models.enums import Permission, RoleType

# Integer ranking for role hierarchy evaluation: VIEWER < MEMBER < ADMIN < OWNER
ROLE_HIERARCHY: Final[dict[RoleType, int]] = {
    RoleType.VIEWER: 1,
    RoleType.MEMBER: 2,
    RoleType.ADMIN: 3,
    RoleType.OWNER: 4,
}

_VIEWER_PERMISSIONS: Final[frozenset[Permission]] = frozenset(
    {
        Permission.WORKSPACE_READ,
        Permission.PROJECT_READ,
        Permission.SPRINT_READ,
        Permission.ISSUE_READ,
        Permission.DOCUMENT_READ,
    }
)

_MEMBER_PERMISSIONS: Final[frozenset[Permission]] = _VIEWER_PERMISSIONS | frozenset(
    {
        Permission.SPRINT_CREATE,
        Permission.SPRINT_UPDATE,
        Permission.ISSUE_CREATE,
        Permission.ISSUE_UPDATE,
        Permission.ISSUE_COMMENT,
        Permission.DOCUMENT_CREATE,
        Permission.DOCUMENT_UPDATE,
    }
)

_ADMIN_PERMISSIONS: Final[frozenset[Permission]] = _MEMBER_PERMISSIONS | frozenset(
    {
        Permission.WORKSPACE_UPDATE,
        Permission.WORKSPACE_MANAGE_MEMBERS,
        Permission.PROJECT_CREATE,
        Permission.PROJECT_UPDATE,
        Permission.PROJECT_DELETE,
        Permission.PROJECT_MANAGE_MEMBERS,
        Permission.SPRINT_DELETE,
        Permission.ISSUE_DELETE,
        Permission.DOCUMENT_DELETE,
    }
)

_OWNER_PERMISSIONS: Final[frozenset[Permission]] = frozenset(Permission)

ROLE_PERMISSIONS: Final[dict[RoleType, frozenset[Permission]]] = {
    RoleType.VIEWER: _VIEWER_PERMISSIONS,
    RoleType.MEMBER: _MEMBER_PERMISSIONS,
    RoleType.ADMIN: _ADMIN_PERMISSIONS,
    RoleType.OWNER: _OWNER_PERMISSIONS,
}


def has_required_role(
    user_role: RoleType | str,
    min_required_role: RoleType | str,
) -> bool:
    """
    Check whether a user's role meets or exceeds a minimum required role in the hierarchy.

    :param user_role: Current role assigned to the user.
    :param min_required_role: Minimum role required for the operation.
    :return: True if user_role level >= min_required_role level, False otherwise.
    """
    try:
        user_enum = (
            user_role if isinstance(user_role, RoleType) else RoleType(user_role)
        )
        req_enum = (
            min_required_role
            if isinstance(min_required_role, RoleType)
            else RoleType(min_required_role)
        )
    except ValueError:
        return False
    return ROLE_HIERARCHY.get(user_enum, 0) >= ROLE_HIERARCHY.get(req_enum, 0)


def role_has_permission(
    role: RoleType | str,
    permission: Permission | str,
) -> bool:
    """
    Check whether a role possesses a specific permission.

    :param role: The RoleType to test.
    :param permission: The Permission to verify.
    :return: True if the role grants the permission, False otherwise.
    """
    try:
        role_enum = role if isinstance(role, RoleType) else RoleType(role)
        perm_enum = (
            permission if isinstance(permission, Permission) else Permission(permission)
        )
    except ValueError:
        return False
    return perm_enum in ROLE_PERMISSIONS.get(role_enum, frozenset())


def get_role_permissions(role: RoleType | str) -> frozenset[Permission]:
    """
    Retrieve all permissions granted to a specific role.

    :param role: The RoleType to inspect.
    :return: Frozen set of permissions for the role.
    """
    try:
        role_enum = role if isinstance(role, RoleType) else RoleType(role)
    except ValueError:
        return frozenset()
    return ROLE_PERMISSIONS.get(role_enum, frozenset())
