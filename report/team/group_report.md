# Báo cáo nhóm — Lab 8 LogiX-VN

Tối đa 5 trang ngoài phụ lục. Số liệu lấy từ file trong `src/reports/`, không chép tay từ terminal.

## 1. Thông tin nhóm

- Tên nhóm: <TenNhom>
- Thành viên: xem `TEAM.md` (4 người: TV1 workflow + integration, TV2 single, TV3 orchestrator + handoff, TV4 ledger + evaluation)
- Commit chốt (trùng `report/team/decision_adr.md`): `<hash>`

## 2. Mục tiêu và cách tiếp cận

Nhóm hiểu bài toán thế nào, chia việc ra sao, thứ tự làm bốn shape.

**Bài toán.** Xử lý claim hoàn phí ship của LogiX-VN bằng bốn kiến trúc có cùng chữ ký `run_claim`, rồi chọn kiến trúc *ít tự chủ nhất mà vẫn đạt yêu cầu* dựa trên số đo. Nhóm coi đây trước hết là bài toán về ranh giới: số tiền, approval, trần theo đơn và chống ghi trùng là việc của **code và host**; model (MockLLM) chỉ được đọc và soạn chữ. Chữ trong ticket là dữ liệu người dùng, không phải lệnh và không phải nguồn số liệu (số ngày trễ, mã đơn).

**Chia việc.** Nhóm 4 người theo gợi ý của đề:

| Họ tên | Phụ trách |
| --- | --- |
| Đặng Thanh Hải - 2A202603570 | Shape A `workflow.py`, tạo repo, merge PR, chạy `check_submission`, chốt commit |
| Nguyễn Đăng Doanh - 2A202603597 | Shape B `single.py` (ReAct ≤ 8 bước) |
| Hoàng Gia Khiêm - 2A202603540| Shape C `orchestrator.py`, handoff an toàn, rà secret/PII trong trace |
| Đoàn Văn Tú - 2A202603595| Crash suite, idempotency, policy test, benchmark, ADR, research card |

**Thứ tự.** Workflow được làm đầu tiên (CP2, 13:45–14:15) và push sớm vì nó là khung chung cho B và C: đọc claim qua view allowlist → tra đơn theo principal → `compute_compensation` → `durability.issue_refund` với quote đầy đủ và `crash_at` → `finish()`. TV2 và TV3 copy phần tính quote, gọi host và ghi trace từ workflow vào file của mình (grader chỉ lấy ba file shape nên không dùng module helper chung). Swarm có sẵn chỉ dùng làm đối chứng cost và variance. Mỗi người làm trên branch riêng, merge vào `main` qua PR; TV1 chạy `python -m pytest -q` sau mỗi lần merge để giữ cổng host xanh.

## 3. Giải pháp

Mô tả ba shape nhóm viết (workflow, single, orchestrator): mỗi shape đọc gì, quyết định gì, gọi host ra sao. Chỉ rõ ranh giới code / model (tham khảo [docs/architecture.md](../../docs/architecture.md)), cách handoff được sanitize và trace ghi những event nào.

### 3A. Workflow (`src/lab8/shapes/workflow.py`)

Các bước Python cố định, không có nhánh nào do model quyết:

| Bước | Đọc / gọi | Quyết định (bởi code) |
| --- | --- | --- |
| 1 | `get_claim_view` (chỉ `claim_id, principal_id, order_id, ticket`, không `SELECT *`) | Không có claim → `failed`, `proposal_amount = 0` |
| 2 | `order_id` của dòng claim | Thiếu → `needs_info`, không ghi ledger. Không đoán mã đơn từ ticket |
| 3 | `lookup_order(order_id, principal_id)` | Không thấy đơn hoặc sai chủ → `escalated`, chỉ trả `reason` |
| 4 | `compute_compensation(order)` (policy `is_current` và `effective_date <= as_of` do host lọc) | Quote = 0 → `denied`, **không** gọi `issue_refund` |
| 5 | `durability.issue_refund(conn, claim_id, quote, crash_at=crash_at)` | Host từ chối → `denied` với `proposal_amount` = quote đầy đủ (host ghi `policy_denied`); `conflict` → `failed`; còn lại → `resolved` |

**Ranh giới code / model.** Workflow có đúng một lời gọi MockLLM (`purpose="draft"`) ở cuối mỗi nhánh để soạn câu trả lời khách. Prompt chỉ chứa `status`; model không thấy ticket, order row hay số tiền, và kết quả của nó không được dùng cho quyết định nào. Số ngày trễ luôn lấy từ order row, nên ticket C-002 ("trễ 5 ngày" trong khi đơn trễ 2 ngày) bị `denied` ở cả 5 seed — đúng chỗ swarm tham chiếu sai ở seed 55.

**Vì sao truyền quote đầy đủ.** Host tự trừ phần mà các claim trước đã nhận cho cùng đơn (trần theo đơn). Nếu shape tự trừ trước thì host trừ lần nữa: T14 (O-515 đã hoàn 30.000, entitlement mới 150.000) sẽ ra 90.000 thay vì 120.000. Workflow vì vậy trả `proposal_amount = 150000` và để ledger ghi 120.000.

**Crash.** `crash_at` được truyền thẳng vào `issue_refund`. `InjectedCrash` không bị nuốt: shape chỉ ghi event `crash` vào trace để lần chạy có trace hợp lệ, rồi `raise` lại. Khi resume, idempotency key `refund:{claim_id}` của host trả `idempotent_replay` nên vẫn một dòng ledger và một audit `refund_committed`.

**Trace.** Dùng `lab8.trace.Trace` với `run_id = make_run_id("workflow", claim_id, seed)`; `finish()` ghi file ở mọi nhánh return. Các event: `claim` (chỉ `found`, `has_order_id`), `lookup_order` (`visible`, `reason`, và order view allowlist khi thấy đơn), `quote` (`amount_vnd`, `reason`, `clause_ids`), `issue_refund` (`ok`, `reason`, `conflict`), `crash` (nếu có), `decision` (`status`, `proposal_amount`, `reason`). Cố ý **không** ghi: ticket, `parent_secret`, `raw_headers`, SĐT, địa chỉ, tên hàng, `internal_note`, nguyên claim row hay order row. `src/tests/test_team_workflow.py` kiểm điều này trên cả 14 claim public.

### 3B. Single agent (`src/lab8/shapes/single.py`)

Một agent chạy `lab8.runtime.run_react` với `max_steps=8`. Hàm `decide` chỉ được chọn tool đọc, theo thứ tự `get_claim_view` → `lookup_order` → `lookup_refund_history`, rồi trả `final`:

| Agent thấy | Agent quyết (dừng vòng lặp) |
| --- | --- |
| `get_claim_view` không có claim | `failed`, `proposal_amount = 0` |
| Dòng claim không có `order_id` | `needs_info`. Không đoán mã đơn từ ticket |
| `lookup_order` không visible (không thấy đơn hoặc sai chủ) | `escalated`, chỉ trả `reason` |
| Đã có order view và lịch sử hoàn tiền | `ready_to_quote`, chuyển cho code |

Vì `run_react` chỉ đưa lại cho `decide` kết quả của tool vừa gọi, `decide` tự giữ một `memory` chứa kết quả các bước trước.

**Ranh giới code / model.** Model chỉ quyết tool đọc nào gọi tiếp và khi nào dừng. Nếu model chọn tool ghi, `dispatch` ném `ToolRejected` và shape trả `failed` thay vì ném exception. Mỗi bước có một lời gọi MockLLM (`purpose="react"`) để Budget tính cost của agent, cộng một lời gọi `draft` ở cuối để soạn câu trả lời. Prompt không chứa ticket, order row hay số tiền. Sau vòng lặp, code tính quote bằng `compute_compensation` từ order row trong DB. Hàm này chỉ dùng policy `is_current` có `effective_date <= as_of`. Agent không gọi `get_clause`, nên không bao giờ trả tiền theo policy cũ hay policy tương lai mà ticket trích dẫn. Sau đó code gọi `durability.issue_refund` với quote đầy đủ và `crash_at`. Agent có đọc `lookup_refund_history` nhưng không dùng số này để trừ quote, vì host đã tự áp trần theo đơn (T14: `proposal_amount` 150.000, ledger 120.000). Từ bước quote trở đi, single xử lý giống hệt workflow (map `denied` / `failed` / `resolved`, không nuốt `InjectedCrash`). Vì vậy khác biệt giữa A và B khi benchmark chỉ đến từ phần đọc do agent điều khiển và số model call thêm vào.

**Trace.** Các event: `react_step` (số bước, tên tool, trạng thái dừng), `refund_history` (chỉ `refund_count`, `refunded_vnd`), `quote` (`amount_vnd`, `reason`, `clause_ids`), `issue_refund` (`ok`, `reason`, `conflict`), `crash` (nếu có), `decision` (`status`, `proposal_amount`, `reason`). Cố ý **không** ghi: ticket, kết quả thô của tool, `memory`, nguyên claim row hay order row, `parent_secret`, `raw_headers`, SĐT, địa chỉ, tên hàng, `internal_note`. `src/tests/test_team_single.py` kiểm tra trace của cả 14 claim public, kiểm tra agent không vượt 8 bước, không chọn tool ghi, không tin số ngày trễ trong ticket (C-002, 5 seed), và vẫn truyền quote đầy đủ ở T14.

### 3C. Orchestrator (`src/lab8/shapes/orchestrator.py`)



## 4. Kết quả

Bảng so sánh 4 shape trên bộ public (từ `src/reports/benchmark.json`): pass rate, pass^5, seed min–max, variance, cost/success, mean/p95 steps. Kèm crash safety (`src/reports/crash.json`) và, nếu có, kết quả tự kiểm trên `student_drop/`.

...

Quyết định kiến trúc và lý do: xem `report/team/decision_adr.md`. Phiếu nghiên cứu và ablation: xem `report/team/research_card.md`.

## 5. Khó khăn và cách xử lý

Lỗi gặp phải (kèm lệnh, output hoặc ảnh chụp) và cách nhóm xử lý.


- *`run_react` chỉ trả kết quả của tool vừa gọi.* Sau mỗi bước, `seen` chỉ có `last_tool` / `last_result`, nên ở bước thứ ba agent không còn thấy dòng claim. Cách xử lý: `decide` là closure giữ một dict `memory` theo tên tool.
- *Lọc test student theo shape bị khớp nhầm.* `pytest -m student -k single` chọn cả `test_public_single_run_cases[...-workflow]` vì tên test chứa chữ `single`, nên ra 120 failed. Cách xử lý: lọc theo tham số shape bằng `-k "single]"`, ra đúng 62 test.

...

## 6. Tổng hợp đóng góp

Chi tiết đóng góp của từng thành viên nằm trong `TEAM.md` (bảng đóng góp) và báo cáo cá nhân `report/team/MSSV_HoTen.md`.

## 7. Hạn chế và hướng cải thiện

MockLLM không phải model sản xuất; latency là `unavailable`. Nêu thêm giới hạn của nhóm và điều kiện làm kết luận thay đổi.

...

## 8. Tài liệu tham khảo

...
