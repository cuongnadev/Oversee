# ADR 0001: Lựa chọn công nghệ cơ sở dữ liệu, ORM và công cụ Migration

- **Trạng thái:** Accepted
- **Ngày quyết định:** 2026-11-14
- **Người tham gia / Stakeholders:** Nhóm phát triển Oversee (Team 04 - Oversee)
- **Epic:** #13 - Database & Domain Modeling
- **Issue liên quan:** #43 - Finalize database technology

---

## 1. Bối cảnh (Context)

Dự án **Oversee** là nền tảng quản lý và theo dõi dự án phần mềm tập trung. Hệ thống phục vụ quản lý đa tầng thực thể bao gồm:
- **Người dùng và phân quyền:** User, Workspace, Project, Workspace Member, Project Member.
- **Quản lý công việc và tiến độ:** Issue, Task, Task Hierarchy (Parent - Child), Sprint, Backlog, Milestone.

Để đảm bảo nền tảng vận hành ổn định, nhất quán và sẵn sàng mở rộng, hệ thống backend (FastAPI, Python 3.14) yêu cầu một tầng dữ liệu đáp ứng các tiêu chuẩn kỹ thuật sau:
1. **Tính toàn vẹn dữ liệu (Data Integrity) & ACID:** Các ràng buộc khóa ngoại (Foreign Keys), ràng buộc duy nhất (Unique constraints, ví dụ: 1 user không thể tham gia trùng lặp 1 workspace), cơ chế cascade xóa/cập nhật dữ liệu phải được đảm bảo nghiêm ngặt ở mức cơ sở dữ liệu.
2. **Khả năng lưu trữ dữ liệu nửa cấu trúc (Semi-structured data):** Cho phép mở rộng metadata, custom fields cho Task/Issue, lưu audit log mà không cần phá vỡ cấu trúc bảng chính.
3. **Hiệu năng tìm kiếm và truy vấn quan hệ phức tạp:** Hỗ trợ tìm kiếm theo từ khóa (Full-Text Search), lọc theo phân cấp cha - con (Recursive Queries / CTE), sắp xếp backlog rank.
4. **Hệ sinh thái đồng bộ với FastAPI & Python 3.14:** Thư viện ORM hiện đại hỗ trợ kiểu dữ liệu tĩnh (Type-safe), async/sync I/O, quản lý connection pool và vòng đời session an toàn.
5. **Quản lý phiên bản cơ sở dữ liệu bằng mã nguồn (Database Migrations):** Cho phép quản lý sự thay đổi schema qua từng phiên bản, tự động hóa trong CI/CD, có khả năng rollback khi cần thiết.

---

## 2. So sánh các lựa chọn (Evaluation of Alternatives)

Nhóm đã tiến hành đánh giá nhanh 4 giải pháp lưu trữ dữ liệu phổ biến:

| Tiêu chí đánh giá | PostgreSQL | MySQL / MariaDB | SQLite | MongoDB (NoSQL) |
|---|---|---|---|---|
| **Mô hình dữ liệu** | Relational (RDBMS) + Object-Relational | Relational (RDBMS) | Relational (File-based) | Document Store (NoSQL) |
| **Tính toàn vẹn ACID** | Rất cao, tuân thủ chuẩn ANSI SQL nghiêm ngặt | Cao | Đầy đủ nhưng khóa ở mức database/file | Cấp document (multi-doc transaction tốn kém) |
| **Hỗ trợ quan hệ & Khóa ngoại** | Toàn diện, cascade rules, composite constraints | Đầy đủ (InnoDB) | Cơ bản (cần bật foreign_keys pragma) | Phải xử lý thủ công ở tầng ứng dụng |
| **Dữ liệu JSON / Custom fields** | Vượt trội với `JSONB`, indexing GIN/GiST | Hỗ trợ JSON cơ bản | Hỗ trợ JSON qua hàm mở rộng | Native BSON/JSON |
| **Kiểu dữ liệu mở rộng** | Native UUID, Array, Timezone UTC chuẩn | UUID giả lập qua BINARY(16)/VARCHAR | Text/Blob | ObjectId/BSON |
| **Hỗ trợ Full-Text Search** | Tích hợp sẵn (tsvector, tsquery) | Có sẵn (FULLTEXT index) | FTS5 extension | Text index |
| **Khả năng đồng thời (Concurrency)** | Cao (MVCC tiên tiến) | Cao (MVCC) | Thấp (chỉ 1 writer tại một thời điểm) | Cao |
| **Tích hợp Python / FastAPI** | SQLAlchemy 2.x, psycopg3, asyncpg rất mạnh | SQLAlchemy + aiomysql/asyncmy | SQLAlchemy / aiosqlite | Motor, Beanie |
| **Độ phù hợp với Oversee** | **Lý tưởng (Tối ưu nhất)** | Tương đối phù hợp | Chỉ phù hợp test đơn giản | Không phù hợp |

### Phân tích chi tiết từng lựa chọn:

1. **PostgreSQL (Lựa chọn được chọn):**
   - Hỗ trợ tốt nhất cho các yêu cầu của Oversee nhờ chuẩn hóa RDBMS, hỗ trợ native UUID v4, kiểu dữ liệu `JSONB` cho metadata của issue, và `tsvector` cho full-text search.
   - Cơ chế Multi-Version Concurrency Control (MVCC) tiên tiến, đáp ứng lượng truy cập đồng thời lớn khi nhiều thành viên tương tác cùng bảng Kanban/Sprint.
   - Hỗ trợ tuyệt vời trên các nền tảng đám mây và Docker container.

2. **MySQL / MariaDB:**
   - Dù phổ biến nhưng hỗ trợ JSON kém tối ưu hơn `JSONB` của PostgreSQL (không có chỉ mục GIN cho key/value con).
   - Xử lý UUID và múi giờ (timezone-aware datetime) đòi hỏi cấu hình phức tạp hơn.

3. **SQLite:**
   - Ưu điểm nhẹ, không cần server tách biệt.
   - Nhược điểm lớn: Khóa toàn bộ database khi ghi (write-lock), không phù hợp cho môi trường multi-user, không đáp ứng được yêu cầu triển khai thực tế của ứng dụng quản lý dự án.

4. **MongoDB:**
   - Mô hình tài liệu (Document) linh hoạt, nhưng miền bài toán của Oversee xoay quanh các mối quan hệ quan trọng (Workspace -> Project -> Member -> Issue -> Sprint) với các ràng buộc tính toán quyền hạn (RBAC) và toàn vẹn tham chiếu. Việc sử dụng MongoDB sẽ chuyển gánh nặng kiểm tra toàn vẹn sang mã ứng dụng, dễ dẫn đến mâu thuẫn dữ liệu (data inconsistency) và truy vấn quan hệ kém hiệu quả.

---

## 3. Quyết định (Decision)

Nhóm quyết định thông qua bộ công nghệ lưu trữ dữ liệu và công cụ đi kèm như sau:

1. **Hệ quản trị cơ sở dữ liệu (Database Engine): PostgreSQL 16+**
   - Được triển khai dưới dạng dịch vụ Docker container (`docker-compose.yml`) cho môi trường phát triển cục bộ và kiểm thử.
   - Sử dụng chuẩn mã hóa ký tự `UTF-8`, thời gian chuẩn hóa theo `UTC`.
   - Lưu trữ khóa chính dưới dạng UUID v4 (chuẩn 128-bit) đảm bảo tính duy nhất và an toàn khi tích hợp hệ thống phân tán.

2. **Thư viện Object-Relational Mapping (ORM): SQLAlchemy 2.x**
   - Áp dụng phong cách khai báo hiện đại (Declarative 2.0 Mapping) với `Mapped[...]` và `mapped_column()` để tận dụng hệ thống type hinting của Python, tương thích tuyệt đối với Pydantic v2.
   - Quản lý session thông qua `sessionmaker` và Dependency Injection trong FastAPI (`get_db`).

3. **Database Driver: `psycopg` (v3 - modern binary driver)**
   - Cài đặt gói `psycopg[binary]>=3.1.0`.
   - Driver thế hệ mới, tối ưu hiệu năng C, hỗ trợ kết nối đồng bộ và sẵn sàng chuyển tiếp sang bất đồng bộ (async).

4. **Công cụ Migration: Alembic**
   - Sử dụng để theo dõi, sinh tự động (`autogenerate`) và áp dụng các bản nâng cấp/hạ cấp lược đồ dữ liệu (`upgrade head`, `downgrade -1`).
   - Mọi thay đổi cấu trúc bảng bắt buộc phải thông qua file migration có kiểm soát phiên bản trong Git, nghiêm cấm chỉnh sửa thủ công trực tiếp trên cơ sở dữ liệu.

---

## 4. Hệ quả & Biện pháp giảm thiểu (Consequences & Mitigations)

### Tích cực:
- **Toàn vẹn và an toàn:** Toàn bộ quan hệ cha - con, ràng buộc thành viên và trạng thái vòng đời issue được quản lý chính xác ở cấp RDBMS.
- **Mã nguồn sạch và rõ ràng:** SQLAlchemy 2.0 cung cấp typing mạnh mẽ, giảm thiểu lỗi runtime do sai kiểu dữ liệu.
- **Khả năng tái lập cao (Reproducibility):** Bất kỳ lập trình viên nào trong nhóm cũng có thể khởi dựng môi trường dữ liệu chuẩn xác chỉ với một lệnh `docker compose up -d` và `uv run alembic upgrade head`.
- **Dễ dàng mở rộng:** Khi cần thêm custom field cho Issue hoặc Sprint, trường `JSONB` của PostgreSQL cho phép mở rộng mà không cần thực hiện migration phức tạp.

### Thách thức & Biện pháp xử lý:
- **Quản lý tài nguyên kết nối (Connection Pool):**
  - *Biện pháp:* Cấu hình thông số pool trong SQLAlchemy (`pool_size=10`, `max_overflow=20`, `pool_pre_ping=True`) nhằm tái sử dụng kết nối và phát hiện kết nối chết kịp thời.
- **Kỷ luật Migration:**
  - *Biện pháp:* Đưa kiểm tra migration vào quy trình review mã nguồn (Pull Request); mọi thay đổi model đều phải đi kèm migration tương ứng.

---

## 5. Lộ trình thực hiện tiếp theo (Next Steps)

Quyết định này là cơ sở để thực hiện các sub-issue tiếp theo trong Epic #13:
- **#44 - Design database ERD:** Thiết kế chi tiết sơ đồ quan hệ thực thể cho toàn bộ domain.
- **#45 - Define base entity and audit fields:** Định nghĩa lớp `Base` dùng chung với UUID và các trường thời gian (`created_at`, `updated_at`, `deleted_at`).
- **#46 - Integrate PostgreSQL:** Thiết lập `docker-compose.yml`, biến môi trường `DATABASE_URL` và tích hợp driver `psycopg`.
- **#47 - Configure database connection and session management:** Triển khai `app/db/session.py` và dependency `get_db`.
- **#48 - Set up SQLAlchemy ORM:** Khởi tạo base model và cấu trúc package `app/models/`.
- **#49 - Configure Alembic migrations:** Cấu hình môi trường migration với Alembic.
- **#50 - #55:** Lần lượt triển khai các domain model: User, Workspace, Project, Membership, Issue/Task, Sprint/Backlog.
- **#56 - Create initial database migration:** Tạo và kiểm thử migration khởi tạo hoàn chỉnh.
- **#57 - Add database integration tests:** Viết bộ kiểm thử tích hợp cơ sở dữ liệu với PostgreSQL.
