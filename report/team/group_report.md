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

| Vai | Phụ trách |
| --- | --- |
| TV1 (nhóm trưởng) | Shape A `workflow.py`, tạo repo, merge PR, chạy `check_submission`, chốt commit |
| TV2 | Shape B `single.py` (ReAct ≤ 8 bước) |
| TV3 | Shape C `orchestrator.py`, handoff an toàn, rà secret/PII trong trace |
| TV4 | Crash suite, idempotency, policy test, benchmark, ADR, research card |

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

*(TV2 điền: vòng `run_react` tối đa 8 bước, `decide` chỉ chọn tool đọc, kiểm `is_current` khi dùng `get_clause`, code tính quote và gọi `issue_refund` sau vòng lặp, cách đếm model call vào Budget, các event trace.)*

### 3C. Orchestrator (`src/lab8/shapes/orchestrator.py`)

*(TV3 điền: `make_handoff` với allowlist field và tool chỉ đọc, investigator chạy gì, orchestrator tính quote và gọi host thế nào, trace chỉ ghi handoff đã sanitize, vì sao tóm tắt bằng LLM không tính là redaction.)*

## 4. Kết quả

Bảng so sánh 4 shape trên bộ public (từ `src/reports/benchmark.json`): pass rate, pass^5, seed min–max, variance, cost/success, mean/p95 steps. Kèm crash safety (`src/reports/crash.json`) và, nếu có, kết quả tự kiểm trên `student_drop/`.

...

Quyết định kiến trúc và lý do: xem `report/team/decision_adr.md`. Phiếu nghiên cứu và ablation: xem `report/team/research_card.md`.

## 5. Khó khăn và cách xử lý

Lỗi gặp phải (kèm lệnh, output hoặc ảnh chụp) và cách nhóm xử lý.

...

## 6. Tổng hợp đóng góp

Chi tiết đóng góp của từng thành viên nằm trong `TEAM.md` (bảng đóng góp) và báo cáo cá nhân `report/team/MSSV_HoTen.md`.

## 7. Hạn chế và hướng cải thiện

MockLLM không phải model sản xuất; latency là `unavailable`. Nêu thêm giới hạn của nhóm và điều kiện làm kết luận thay đổi.

...

## 8. Tài liệu tham khảo

...
