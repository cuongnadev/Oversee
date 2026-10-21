# Git Workflow Guide — Oversee

**Mục đích:** Quy định cách Developer và Lead làm việc với Git/GitHub, từ nhận Issue đến merge code vào `master`.

**Phạm vi:** Oversee Backend — Python, `uv`, FastAPI, pytest và Ruff.

## 1. Branch strategy

Dự án sử dụng hai nhánh chính:

- `master`: nhánh ổn định. Chỉ Lead được merge `develop` vào `master` sau khi review và xác nhận đạt yêu cầu.
- `develop`: nhánh tích hợp công việc của nhóm. Các feature/fix/docs branch được tạo từ `develop` và mở Pull Request (PR) về `develop`.

Luồng làm việc:

```text
master
  └── develop
       ├── feat/<short-description>  ── PR ──> develop
       ├── fix/<short-description>   ── PR ──> develop
       └── docs/<short-description>  ── PR ──> develop

Lead reviews develop
       └── PR: develop ──> master
```

**Quy tắc bắt buộc**
- Developer không commit trực tiếp lên `master` hoặc `develop`.
- Branch công việc được tạo từ `develop`.
- PR của Developer phải có base branch là `develop`.
- Chỉ Lead quyết định và thực hiện merge `develop` vào `master`.
- Không merge khi test/CI bắt buộc thất bại hoặc còn review blocker.

## 2. Bắt đầu một Issue

Trước khi code, đọc Issue và xác nhận:
- Mục tiêu và acceptance criteria.
- Phạm vi công việc.
- Test cần bổ sung/cập nhật.
- Dependencies hoặc quyết định kiến trúc cần Lead xác nhận.

Nếu yêu cầu chưa rõ, hỏi Lead trước khi tự thay đổi API contract hoặc kiến trúc dùng chung.

## 3. Đồng bộ `develop` và tạo branch

Chạy từ repository root:

```powershell
git status
git switch develop
git fetch origin
git pull --ff-only origin develop
git status
```

Nếu có thay đổi local chưa xử lý, dừng lại và xác định cách giữ chúng trước khi đổi branch. Không dùng `git reset --hard` để xử lý nhanh.

Tạo branch theo loại công việc và mô tả ngắn:

| Loại | Prefix | Ví dụ |
|---|---|---|
| Tính năng | `feat/` | `feat/task-create-endpoint` |
| Sửa lỗi | `fix/` | `fix/health-check-status` |
| Tài liệu | `docs/` | `docs/backend-setup-guide` |
| Test | `test/` | `test/task-service` |
| Refactor | `refactor/` | `refactor/config-loading` |
| Bảo trì/cấu hình | `chore/` | `chore/backend-tooling` |
| CI | `ci/` | `ci/backend-workflow` |

Tạo branch từ `develop` đã cập nhật:

```powershell
git switch -c feat/task-create-endpoint
git branch --show-current
git status
```

Dùng chữ thường và dấu gạch ngang. Tên branch không cần chứa mã Issue hoặc tên người thực hiện.

## 4. Code và chạy kiểm tra

Thực hiện thay đổi trong phạm vi Issue. Bổ sung test cho hành vi mới và trường hợp lỗi quan trọng. Không commit `.env`, secrets, token, API key, file tạm hoặc thay đổi không liên quan.

Kiểm tra thay đổi thường xuyên:

```powershell
git status
git diff
git diff --stat
```

Với backend, chạy các lệnh từ thư mục `backend` (nơi có `pyproject.toml`):

```powershell
uv sync --dev
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

Các lệnh trên giả định pytest và Ruff đã được khai báo trong cấu hình dự án. Nếu chưa có hoặc lệnh thất bại do cấu hình, báo Lead hoặc xử lý trong Issue tooling phù hợp; không đánh dấu test là pass nếu chưa chạy thành công.

Nếu cần kiểm tra ứng dụng thủ công:

```powershell
uv run uvicorn app.main:app --reload
```

Kiểm tra endpoint theo acceptance criteria và code hiện có; dừng server bằng `Ctrl+C`.

Trước khi commit, xem lại diff và chạy:

```powershell
git diff --check
git status --short
```

## 5. Commit convention

Dùng Conventional Commits:

```text
<type>(<scope>): <short summary>
```

Ví dụ:

```text
feat(tasks): add task creation endpoint
fix(api): handle invalid task identifier
test(config): cover settings validation
docs(backend): document local setup
chore(backend): configure development tooling
ci(backend): run tests on pull requests
refactor(config): simplify settings access
```

Các `type` thường dùng:

- `feat`: tính năng mới.
- `fix`: sửa lỗi.
- `docs`: tài liệu.
- `test`: kiểm thử.
- `refactor`: tái cấu trúc không đổi hành vi dự kiến.
- `style`: formatting/style không đổi logic.
- `chore`: bảo trì, cấu hình, dependencies.
- `ci`: pipeline CI/CD.
- `build`: hệ thống build/package.
- `perf`: cải thiện hiệu năng.
- `revert`: hoàn tác commit.

Quy tắc:
- Message bằng tiếng Anh, rõ ràng, dùng động từ nguyên mẫu như `add`, `fix`, `configure`.
- Mỗi commit tập trung vào một thay đổi logic.
- Scope mô tả phần bị ảnh hưởng, ví dụ `api`, `config`, `tasks`, `tests`, `backend`.
- Không dùng message mơ hồ như `update code` hoặc `fix stuff`.

### Stage và commit

Kiểm tra file trước khi stage:

```powershell
git status
git diff
```

Stage đúng file cần commit:

```powershell
git add src/app/api/router.py
git add tests/
git status
git diff --cached
```

Chỉ dùng `git add .` khi đã kiểm tra và chắc chắn mọi thay đổi đều thuộc cùng mục đích.

Tạo commit:

```powershell
git commit -m "feat(api): add versioned API router"
git log -1 --oneline
git status
```

Thay ví dụ bằng nội dung thay đổi thực tế.

## 6. Push branch

Push branch lên GitHub lần đầu:

```powershell
git push -u origin feat/task-create-endpoint
```

Các lần sau:

```powershell
git push
```

Thay branch mẫu bằng branch hiện tại. Nếu push bị từ chối, kiểm tra trạng thái và lịch sử trước; không force-push hoặc viết lại lịch sử branch dùng chung khi chưa phối hợp với Lead.

## 7. Mở Pull Request vào `develop`

Trên GitHub:

1. Mở repository Oversee và chọn **Pull requests → New pull request**.
2. Chọn **base: `develop`**.
3. Chọn **compare: branch công việc của bạn**.
4. Xem lại danh sách file thay đổi.
5. Điền title và mô tả.
6. Gán reviewer theo phân công của nhóm.
7. Tạo PR và theo dõi CI/review.

Title dùng Conventional Commits, ví dụ:

```text
feat(tasks): add task creation endpoint
```

Dùng mẫu mô tả sau:

```markdown
## Summary
- What changed?
- Why is it needed?

## Testing
- [ ] `uv run pytest`
- [ ] `uv run ruff check .`
- [ ] `uv run ruff format --check .`
- [ ] Manual verification, if applicable

## Checklist
- [ ] Acceptance criteria are met.
- [ ] Tests are added or updated where needed.
- [ ] Documentation/configuration is updated where needed.
- [ ] No secrets or unrelated files are included.
- [ ] I reviewed my own diff.
```

Chỉ đánh dấu các kiểm tra đã thực hiện. Không ghi kết quả test không đúng sự thật.

## 8. Xử lý review và cập nhật PR

- Đọc và xử lý mọi comment; hỏi Lead nếu phản hồi ảnh hưởng kiến trúc hoặc scope.
- Sửa code và test liên quan.
- Chạy lại kiểm tra phù hợp.
- Commit thay đổi lên cùng branch và push; PR sẽ tự cập nhật.
- Trả lời comment và resolve conversation khi vấn đề đã được xử lý.

Ví dụ:

```powershell
git status
uv run pytest
uv run ruff check .
uv run ruff format --check .
git diff
git add src/app tests
git commit -m "fix(tasks): address review feedback"
git push
```

Chỉ stage các file thực sự thuộc phần sửa review.

## 9. Điều kiện merge PR Developer

PR chỉ được merge vào `develop` khi:
- Acceptance criteria đã đạt.
- Test và CI bắt buộc pass.
- Đã có approval theo quy định nhóm.
- Review blocker đã được giải quyết.
- Không có secrets hoặc thay đổi ngoài phạm vi.
- Không còn merge conflict.

Developer không tự merge `develop` vào `master`.

## 10. Quy trình Lead đưa `develop` vào `master`

Lead chịu trách nhiệm tích hợp bản ổn định:

1. Kiểm tra các PR đã merge vào `develop`, CI và trạng thái test.
2. Review tổng thể các thay đổi tích hợp, API contract, cấu hình và tài liệu.
3. Xử lý hoặc yêu cầu xử lý các lỗi/blocker trước khi phát hành.
4. Mở PR với **base: `master`** và **compare: `develop`**.
5. Mô tả phạm vi thay đổi, kết quả kiểm tra và rủi ro còn lại.
6. Chờ CI và hoàn thành review cuối.
7. Chỉ Lead merge PR này vào `master` khi xác nhận đạt yêu cầu.

Sau khi merge, đồng bộ local:

```powershell
git switch master
git fetch origin
git pull --ff-only origin master
git status

git switch develop
git pull --ff-only origin develop
```

Nếu có thay đổi local chưa xử lý, dừng lại và xử lý an toàn trước khi đồng bộ.

## 11. Xử lý tình huống thường gặp

**Có thay đổi local chưa commit:** kiểm tra `git status` và `git diff`; commit hoặc stash có chủ đích trước khi đổi branch.

**Merge conflict:** xem từng file, giải quyết marker conflict, kiểm tra logic rồi chạy test. Không chọn toàn bộ “ours” hoặc “theirs” mà không hiểu hậu quả.

**Test thất bại:** đọc lỗi, xác định nguyên nhân, sửa code hoặc cấu hình và chạy lại. Không xóa test chỉ để CI pass.

**Push bị từ chối:** fetch và kiểm tra lịch sử; phối hợp với Lead nếu branch có commit khác. Không force-push tùy tiện.

**Lỡ commit secret:** báo Lead ngay, thu hồi/rotate secret và làm theo quy trình xử lý sự cố. Xóa file ở commit sau không đủ để xem secret đã an toàn.

## 12. Checklist

### Trước khi code
- [ ] Đã đọc Issue và acceptance criteria.
- [ ] Đã cập nhật `develop`.
- [ ] Đã tạo branch từ `develop`.

### Trước khi commit
- [ ] Diff chỉ gồm thay đổi liên quan.
- [ ] Không có secrets hoặc file ngoài phạm vi.
- [ ] Test/lint phù hợp đã chạy.
- [ ] Commit message đúng Conventional Commits.

### Trước khi tạo PR
- [ ] Branch đã được push.
- [ ] Base branch là `develop`.
- [ ] PR có Summary và kết quả Testing.
- [ ] Đã tự review diff.

### Trước khi merge
- [ ] CI/test bắt buộc pass.
- [ ] Đã có approval.
- [ ] Review blocker và conflict đã được xử lý.

### Sau khi Lead merge `develop` vào `master`
- [ ] Đồng bộ local `master` và `develop`.
- [ ] Xác nhận working tree sạch.
- [ ] Xóa branch công việc đã merge nếu không còn cần thiết.

## 13. Tài liệu tham khảo

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git documentation](https://git-scm.com/doc)
- [GitHub Pull Requests](https://docs.github.com/en/pull-requests)
- [uv documentation](https://docs.astral.sh/uv/)
- [pytest documentation](https://docs.pytest.org/)
- [Ruff documentation](https://docs.astral.sh/ruff/)
