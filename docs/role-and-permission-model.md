# Role and Permission Model (RBAC)

Tài liệu thiết kế mô hình phân quyền dựa trên vai trò (Role-Based Access Control - RBAC) cho hệ thống **Oversee**.

---

## 1. Mục tiêu và Kiến trúc tổng quan

Oversee áp dụng mô hình phân quyền RBAC phân cấp theo 2 ngữ cảnh (Scopes) độc lập:
1. **Workspace Scope**: Quản lý không gian làm việc, cấu hình tổ chức, thành viên workspace và danh sách dự án.
2. **Project Scope**: Quản lý dự án cụ thể, thành viên dự án, sprint và các issue/task.

Hệ thống cho phép kết hợp cả hai cơ chế kiểm tra:
- **Phân cấp vai trò (Role Hierarchy)**: Đánh giá theo cấp bậc tối thiểu yêu cầu (`VIEWER < MEMBER < ADMIN < OWNER`).
- **Phân quyền chi tiết (Granular Permissions)**: Đánh giá theo từng hành động cụ thể thông qua ma trận quyền `ROLE_PERMISSIONS`.

---

## 2. Định nghĩa vai trò (Roles) & Thứ bậc (Hierarchy)

Các vai trò được định nghĩa qua `RoleType` (`app.models.enums.RoleType`):

| Role | Mức bậc (Level) | Ý nghĩa trong Workspace | Ý nghĩa trong Project |
| :--- | :---: | :--- | :--- |
| **`OWNER`** | 4 | Chủ sở hữu Workspace. Toàn quyền quản trị, chuyển quyền sở hữu, xóa Workspace. | Trưởng dự án / Project Lead. Toàn quyền quản lý cấu hình và xóa Project. |
| **`ADMIN`** | 3 | Quản trị viên Workspace. Mời/xóa thành viên, tạo dự án mới, cập nhật thông tin Workspace. | Quản trị viên dự án. Mời/xóa thành viên dự án, quản lý sprint và mọi issue. |
| **`MEMBER`** | 2 | Thành viên thông thường. Tham gia cộng tác, tạo sprint/issue trong dự án được chỉ định. | Thành viên dự án. Tạo, cập nhật trạng thái issue, tham gia sprint backlog. |
| **`VIEWER`** | 1 | Người xem (chỉ đọc). Chỉ có quyền quan sát, không được tạo mới hoặc chỉnh sửa dữ liệu. | Người xem dự án (chỉ đọc). Chỉ có quyền xem issue, sprint, báo cáo tiến độ. |

Thứ tự phân cấp:
$$\text{VIEWER (1)} < \text{MEMBER (2)} < \text{ADMIN (3)} < \text{OWNER (4)}$$

---

## 3. Danh mục quyền chi tiết (Permission Enum)

Enum `Permission` (`app.models.enums.Permission`) định nghĩa các quyền thao tác nguyên tử:

### 3.1. Workspace Permissions
- `workspace:read`: Xem thông tin chi tiết và danh sách thành viên của Workspace.
- `workspace:update`: Cập nhật tên, mô tả, cấu hình của Workspace.
- `workspace:delete`: Xóa bỏ hoàn toàn Workspace (chỉ dành cho Owner).
- `workspace:manage_members`: Mời thành viên mới, cập nhật role hoặc xóa thành viên khỏi Workspace.

### 3.2. Project Permissions
- `project:create`: Tạo dự án mới bên trong Workspace.
- `project:read`: Xem thông tin chi tiết, thành viên và các tài nguyên của Project.
- `project:update`: Cập nhật tên, mô tả, cài đặt của Project.
- `project:delete`: Xóa bỏ Project.
- `project:manage_members`: Thêm, cập nhật role hoặc xóa thành viên khỏi Project.

### 3.3. Sprint Permissions
- `sprint:create`: Tạo sprint mới trong Project.
- `sprint:read`: Xem danh sách và chi tiết các sprint.
- `sprint:update`: Cập nhật nội dung sprint, kích hoạt (start) hoặc hoàn thành (complete) sprint.
- `sprint:delete`: Xóa sprint.

### 3.4. Issue Permissions
- `issue:create`: Tạo mới issue/task/bug trong Project.
- `issue:read`: Xem danh sách và chi tiết các issue.
- `issue:update`: Cập nhật trạng thái, độ ưu tiên, người thực hiện, mô tả của issue.
- `issue:delete`: Xóa issue.
- `issue:comment`: Đăng bình luận hoặc thảo luận trong issue.

---

## 4. Ma trận quyền hạn (Role-Permission Matrix)

Bảng đối chiếu quyền hạn chi tiết cho từng vai trò trong hệ thống:

| Permission | `VIEWER` | `MEMBER` | `ADMIN` | `OWNER` |
| :--- | :---: | :---: | :---: | :---: |
| **`workspace:read`** | ✅ | ✅ | ✅ | ✅ |
| **`workspace:update`** | ❌ | ❌ | ✅ | ✅ |
| **`workspace:delete`** | ❌ | ❌ | ❌ | ✅ |
| **`workspace:manage_members`** | ❌ | ❌ | ✅ | ✅ |
| **`project:create`** | ❌ | ❌ | ✅ | ✅ |
| **`project:read`** | ✅ | ✅ | ✅ | ✅ |
| **`project:update`** | ❌ | ❌ | ✅ | ✅ |
| **`project:delete`** | ❌ | ❌ | ✅ | ✅ |
| **`project:manage_members`** | ❌ | ❌ | ✅ | ✅ |
| **`sprint:create`** | ❌ | ✅ | ✅ | ✅ |
| **`sprint:read`** | ✅ | ✅ | ✅ | ✅ |
| **`sprint:update`** | ❌ | ✅ | ✅ | ✅ |
| **`sprint:delete`** | ❌ | ❌ | ✅ | ✅ |
| **`issue:create`** | ❌ | ✅ | ✅ | ✅ |
| **`issue:read`** | ✅ | ✅ | ✅ | ✅ |
| **`issue:update`** | ❌ | ✅ | ✅ | ✅ |
| **`issue:delete`** | ❌ | ❌ | ✅ | ✅ |
| **`issue:comment`** | ❌ | ✅ | ✅ | ✅ |

---

## 5. Ánh xạ API Endpoints với Quyền Yêu Cầu

Mỗi API endpoint trong hệ thống Oversee được xác định rõ yêu cầu về quyền và vai trò tối thiểu:

### 5.1. Authentication & Users
| Phương thức & Endpoint | Quyền / Điều kiện | Ghi chú |
| :--- | :--- | :--- |
| `POST /api/v1/auth/register` | Public | Đăng ký tài khoản |
| `POST /api/v1/auth/login` | Public | Đăng nhập lấy access/refresh token |
| `POST /api/v1/auth/refresh` | Refresh Token hợp lệ | Xoay vòng cấp token mới |
| `POST /api/v1/auth/logout` | Authenticated | Thu hồi token |
| `GET /api/v1/users/me` | Authenticated | Lấy thông tin user hiện tại |
| `PATCH /api/v1/users/me` | Authenticated | Cập nhật tên/avatar user hiện tại |

### 5.2. Workspaces
| Phương thức & Endpoint | Permission | Role tối thiểu |
| :--- | :--- | :--- |
| `POST /api/v1/workspaces` | Authenticated User | Bất kỳ user nào đăng nhập (trở thành `OWNER`) |
| `GET /api/v1/workspaces` | Authenticated User | Trả về các workspace mà user là thành viên |
| `GET /api/v1/workspaces/{id}` | `workspace:read` | `VIEWER` |
| `PATCH /api/v1/workspaces/{id}` | `workspace:update` | `ADMIN` |
| `DELETE /api/v1/workspaces/{id}` | `workspace:delete` | `OWNER` |
| `GET /api/v1/workspaces/{id}/members` | `workspace:read` | `VIEWER` |
| `POST /api/v1/workspaces/{id}/members` | `workspace:manage_members` | `ADMIN` |
| `PATCH /api/v1/workspaces/{id}/members/{user_id}`| `workspace:manage_members` | `ADMIN` (Không được hạ role của `OWNER`) |
| `DELETE /api/v1/workspaces/{id}/members/{user_id}`| `workspace:manage_members`| `ADMIN` (Không được xóa `OWNER`) |

### 5.3. Projects
| Phương thức & Endpoint | Permission | Role tối thiểu |
| :--- | :--- | :--- |
| `POST /api/v1/workspaces/{ws_id}/projects` | `project:create` | `ADMIN` (Workspace) |
| `GET /api/v1/workspaces/{ws_id}/projects` | `workspace:read` | `VIEWER` (Workspace) |
| `GET /api/v1/projects/{id}` | `project:read` | `VIEWER` (Project) |
| `PATCH /api/v1/projects/{id}` | `project:update` | `ADMIN` (Project) |
| `DELETE /api/v1/projects/{id}` | `project:delete` | `OWNER` (Project) / `ADMIN` (Workspace) |
| `GET /api/v1/projects/{id}/members` | `project:read` | `VIEWER` (Project) |
| `POST /api/v1/projects/{id}/members` | `project:manage_members` | `ADMIN` (Project) |
| `PATCH /api/v1/projects/{id}/members/{user_id}` | `project:manage_members` | `ADMIN` (Project) |
| `DELETE /api/v1/projects/{id}/members/{user_id}`| `project:manage_members` | `ADMIN` (Project) |

### 5.4. Sprints
| Phương thức & Endpoint | Permission | Role tối thiểu |
| :--- | :--- | :--- |
| `POST /api/v1/projects/{project_id}/sprints` | `sprint:create` | `MEMBER` (Project) |
| `GET /api/v1/projects/{project_id}/sprints` | `sprint:read` | `VIEWER` (Project) |
| `GET /api/v1/sprints/{id}` | `sprint:read` | `VIEWER` (Project) |
| `PATCH /api/v1/sprints/{id}` | `sprint:update` | `MEMBER` (Project) |
| `DELETE /api/v1/sprints/{id}` | `sprint:delete` | `ADMIN` (Project) |

### 5.5. Issues
| Phương thức & Endpoint | Permission | Role tối thiểu |
| :--- | :--- | :--- |
| `POST /api/v1/projects/{project_id}/issues` | `issue:create` | `MEMBER` (Project) |
| `GET /api/v1/projects/{project_id}/issues` | `issue:read` | `VIEWER` (Project) |
| `GET /api/v1/issues/{id}` | `issue:read` | `VIEWER` (Project) |
| `PATCH /api/v1/issues/{id}` | `issue:update` | `MEMBER` (Project) |
| `DELETE /api/v1/issues/{id}` | `issue:delete` | `ADMIN` (Project) hoặc Tác giả |
| `POST /api/v1/issues/{id}/comments` | `issue:comment` | `MEMBER` (Project) |

---

## 6. Lập trình và Sử dụng trong Code

Module `app.core.permissions` cung cấp các hàm tiện ích:

```python
from app.core.permissions import (
    Permission,
    get_role_permissions,
    has_required_role,
    role_has_permission,
)
from app.models.enums import RoleType

# 1. Kiểm tra theo phân cấp role
assert has_required_role(RoleType.OWNER, RoleType.ADMIN) is True
assert has_required_role(RoleType.VIEWER, RoleType.MEMBER) is False

# 2. Kiểm tra theo quyền cụ thể
assert role_has_permission(RoleType.MEMBER, Permission.ISSUE_CREATE) is True
assert role_has_permission(RoleType.VIEWER, Permission.ISSUE_CREATE) is False

# 3. Lấy tập hợp quyền của một role
permissions = get_role_permissions(RoleType.ADMIN)
assert Permission.PROJECT_CREATE in permissions
```
