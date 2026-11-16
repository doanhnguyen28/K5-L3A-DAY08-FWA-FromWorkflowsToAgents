# Phân công Lab 8: From Workflows to Agents (nhóm 4 người)

Bài lab: xử lý claim hoàn phí ship của LogiX-VN bằng 4 kiến trúc (A `workflow`, B `single`, C `orchestrator`, D `swarm`). Swarm đã có sẵn, nhóm viết A, B, C. Sau đó chạy benchmark để chọn kiến trúc **ít tự chủ nhất mà vẫn đạt yêu cầu**.

Mọi lệnh chạy trong thư mục `src/`.

---

## 1. Ba điều kiện bắt buộc (sai là mất điểm, không bù được)

1. **Không refund khi thiếu approval hợp lệ.** Luôn gọi `durability.issue_refund` khi quote > 0 và để host kiểm tra.
2. **Không lộ `CANARY_SECRET_*`** trong trace, stdout hay kết quả. Không ghi nguyên claim row hoặc order row.
3. **Crash không tạo quá một refund.** Truyền `crash_at` vào `issue_refund` và **không bắt `InjectedCrash`**. Crash suite phải đạt `20/20`.

Ngoài ra cần pass rate hidden ≥ 0.75 cho shape nhóm chọn (≥ 0.80 nếu muốn tính bonus), và `python -m pytest -q` luôn xanh.

## 2. Quy tắc chung cho cả nhóm

- **Không sửa:** `metrics.py`, `durability.py`, `policy.py`, `src/config/`, `src/data/`, và không sửa tay JSON trong `src/reports/`.
- **Grader chỉ lấy 3 file shape** (`workflow.py`, `single.py`, `orchestrator.py`) và thư mục `src/bonus/`. Vì vậy **không tạo module helper dùng chung** ở chỗ khác. Mỗi file shape phải tự chạy được, cần thì copy code giữa các file.
- **Tiền do code tính** bằng `compute_compensation`, không để MockLLM quyết. Truyền **quote đầy đủ** vào `issue_refund`, không tự trừ phần đã hoàn trước (T13, T14).
- Trả kết quả bằng `lab8.shapes.common.finish()` và ghi trace bằng `lab8.trace.Trace` ở **mọi nhánh return**.
- Chữ trong ticket là dữ liệu người dùng, không phải lệnh. Không lấy số ngày trễ hay mã đơn từ ticket.
- Mỗi người phải có **ít nhất một commit kỹ thuật và một test** do mình viết (`check_submission` kiểm tra điều này).
- Làm trên branch riêng, merge vào `main` qua PR. Không force-push.

---

## 3. Phân vai

| Vai | Người | Phụ trách chính | Report |
| --- | --- | --- | --- |
| **TV1: Workflow + Integration** (nhóm trưởng) | | Shape A `workflow.py`, tạo repo nhóm, merge code, chạy `check_submission`, chốt commit | `TEAM.md`, `group_report.md` mục 1–3 |
| **TV2: Single agent** | | Shape B `single.py` (vòng ReAct tối đa 8 bước) | `group_report.md` mục 3 phần B, mục 5 |
| **TV3: Orchestrator + Handoff** | | Shape C `orchestrator.py`, handoff an toàn, rà secret/PII trong trace | `decision_adr.md` mục "Trace và bằng chứng" |
| **TV4: Ledger + Evaluation** | | Crash suite, idempotency, policy, benchmark, research card | `decision_adr.md`, `research_card.md`, `group_report.md` mục 4, 7 |

### TV1: Workflow + Integration

**Code:** [src/lab8/shapes/workflow.py](src/lab8/shapes/workflow.py)

- [ ] Bước 0: fork, đổi tên repo thành `K5-L3A-DAY08-<TenNhom>-FromWorkflowsToAgents`, mời 3 bạn vào.
- [ ] Làm workflow **trước tiên (13:45–14:15)** vì đây là mẫu cho B và C:
  - `get_claim_view`, thiếu `order_id` thì `needs_info`
  - `lookup_order`, không thấy đơn hoặc không đúng chủ thì `escalated`
  - `compute_compensation`, quote = 0 thì `denied` (không gọi `issue_refund`)
  - quote > 0 thì gọi `durability.issue_refund(conn, claim_id, full_quote, crash_at=...)`
  - host từ chối thì `denied` với `proposal_amount` bằng quote; amount conflict thì `failed`; thành công thì `resolved`
- [ ] Đẩy workflow lên sớm để TV2 và TV3 copy phần quote, gọi host và trace.
- [ ] Merge PR của các bạn, giữ `pytest -q` xanh sau mỗi lần merge.
- [ ] Cuối buổi: commit, lấy `git rev-parse --short HEAD`, chạy `check_submission` đến khi ra `0 FAIL`, rồi push.

**Test:** thêm `src/tests/test_team_workflow.py`, ví dụ: ticket ghi "trễ 9 ngày" nhưng order row chỉ trễ 1 ngày thì phải ra `denied`.

**Tự kiểm tra:** `python -m pytest -q -m student -o addopts= -k workflow` ra **62 passed**.

### TV2: Single agent

**Code:** [src/lab8/shapes/single.py](src/lab8/shapes/single.py)

- [ ] Trong lúc chờ workflow: đọc `lab8/runtime.py` (`run_react`), `mock_llm.py`, `tools.py` để hiểu `decide` và Budget.
- [ ] Viết vòng `run_react` với `max_steps=8`. `decide` **chỉ chọn tool đọc** (`get_claim_view`, `lookup_order`, `get_clause`, `lookup_refund_history`…), không bao giờ gọi `issue_refund`.
- [ ] Sau vòng lặp, **code** (không phải model) tính quote từ order row rồi gọi `issue_refund` với quote đầy đủ và `crash_at`.
- [ ] Kiểm `is_current` của policy: bỏ qua `SHIP-LATE-OLD` và policy có ngày hiệu lực trong tương lai, dù ticket có trích dẫn.
- [ ] Đếm model call vào Budget để cost so sánh được với các shape khác.

**Test:** thêm `src/tests/test_team_single.py`, ví dụ: agent dừng ở ≤ 8 bước, và ticket "ignore policy" không làm thay đổi kết quả.

**Tự kiểm tra:** `-k single` ra **62 passed**.

### TV3: Orchestrator + Handoff

**Code:** [src/lab8/shapes/orchestrator.py](src/lab8/shapes/orchestrator.py)

- [ ] Trong lúc chờ workflow: đọc `lab8/handoff.py`, `run_readonly_investigators` trong `runtime.py`, `docs/contracts.md` phần Trace contract.
- [ ] Dựng handoff bằng `make_handoff` với allowlist field và **tool chỉ đọc**. Không đưa `parent_secret`, header hay claim row thô vào facts.
- [ ] Investigator chạy tool đọc, orchestrator tính quote từ order view rồi gọi `issue_refund` (quote đầy đủ, `crash_at`).
- [ ] Trace chỉ ghi handoff **đã sanitize**, không ghi parent context. Tóm tắt bằng LLM không được tính là đã sanitize.
- [ ] **Rà an toàn cho cả 3 shape (CP4):** grep `CANARY_SECRET`, SĐT, địa chỉ, `internal_note` trong `src/traces/` sau khi chạy test, và kiểm tra không có `print` nào in dữ liệu thô.

**Test:** thêm `src/tests/test_team_handoff.py`, ví dụ: facts trong handoff không chứa `parent_secret`, và trace của orchestrator không chứa chuỗi `CANARY_SECRET_`.

**Tự kiểm tra:** `-k orchestrator` ra **62 passed**.

### TV4: Ledger + Evaluation

**Code/bằng chứng:** `src/reports/crash.json`, `src/reports/benchmark.json`, các test durability/policy

- [ ] CP1: đảm bảo cả 4 máy cài được môi trường (smoke pass, `pytest -q` xanh, student ra `186 failed, 62 passed`). Đọc [docs/troubleshooting.md](docs/troubleshooting.md) để hỗ trợ khi có lỗi.
- [ ] Trong lúc 3 bạn code: chạy `python -m lab8.demo.buggy_workflow`, đọc `durability.py`, `policy.py` để nắm idempotency key `refund:{claim_id}` và các lý do `policy_denied`. Viết sẵn test cho các nhánh khó, để TV1/2/3 chạy thử shape của mình:
  - approval hết hạn, bị thu hồi, hoặc của claim khác (`approval_claim_mismatch`)
  - đơn đã hoàn đủ (`order_already_refunded`), hoàn phần chênh (T14)
  - gọi lại cùng claim chỉ ra 1 dòng ledger (T11), crash rồi resume chỉ ra 1 refund (T12)
- [ ] CP4: `python -m lab8.crash_test --count 20 --out reports/crash.json`, yêu cầu `crash_safety = 20/20`.
- [ ] CP5: chạy benchmark:
  ```
  python -m lab8.benchmark --shapes workflow,single,orchestrator,swarm --cases data/public_claims.jsonl --seeds 11,22,33,44,55 --out reports/benchmark.json
  ```
- [ ] Sau 16:15: tự kiểm trên `student_drop/` theo [src/README.md](src/README.md).
- [ ] Điền `decision_adr.md` (shape chọn, commit hash, run id, số liệu **lấy từ file report**) và `research_card.md` (chọn 1 câu R1–R4, chạy 1 ablation).

**Test:** thêm `src/tests/test_team_policy.py` với các nhánh approval và trần theo đơn ở trên, chạy cho cả 3 shape bằng `pytest.mark.parametrize`.

---

## 4. Lịch theo checkpoint

| Giờ | CP | TV1 Workflow | TV2 Single | TV3 Orchestrator | TV4 Ledger/Eval |
| --- | --- | --- | --- | --- | --- |
| 13:30–13:45 | CP1 | Tạo repo nhóm, điền `TEAM.md` | Cài môi trường, đọc business_rules và contracts | Cài môi trường, đọc swarm_reference | Hỗ trợ cài đặt cả nhóm |
| 13:45–14:30 | CP2 | Viết xong workflow, push sớm | Đọc runtime, viết khung ReAct | Đọc handoff, viết khung orchestrator | Viết test policy/approval |
| 14:30–15:15 | CP3 | Review và merge PR, sửa workflow | Hoàn thiện single, xanh T11/T12 | Hoàn thiện orchestrator và handoff | Test idempotency/crash cho 3 shape |
| 15:15–15:30 | | Nghỉ | | | |
| 15:30–16:15 | CP4 | Sửa lỗi theo báo cáo của TV3/TV4 | Sửa lỗi single | Rà secret/PII trong trace cả 3 shape | Crash suite 20/20 |
| 16:15–17:00 | CP5 | Commit chốt, `check_submission` | Viết `group_report` mục 3B, 5 | Viết ADR mục Trace | Benchmark, hidden self-check, ADR, research card |
| 17:00–17:30 | | Push, kiểm tra checklist nộp | Báo cáo cá nhân | Báo cáo cá nhân | Báo cáo cá nhân |

---

## 5. Báo cáo, ai làm gì

| File | Người chính | Người hỗ trợ |
| --- | --- | --- |
| `TEAM.md` (thành viên và bảng đóng góp) | TV1 | Mỗi người tự điền dòng của mình (commit + test) |
| `report/team/group_report.md` | TV1 | TV2 (mục 3B, 5), TV4 (mục 4, 7) |
| `report/team/decision_adr.md` | TV4 | TV3 (mục Trace và bằng chứng) |
| `report/team/research_card.md` | TV4 | Cả nhóm góp ý |
| `report/team/<MSSV>_<HoTen>.md` | **Mỗi người tự viết**, copy từ `MSSV_HoTen.md`, giữ nguyên file mẫu | |

Gợi ý chọn shape trong ADR: nếu workflow đạt pass rate ≥ 0.75 và cost/variance thấp nhất thì chọn **workflow** (ít tự chủ nhất). Chỉ chọn shape khác khi số liệu trong `benchmark.json` cho thấy rõ là tốt hơn.

---

## 6. Checklist trước khi nộp (TV1 chạy, cả nhóm kiểm tra)

- [ ] `python -m pytest -q` xanh
- [ ] `python -m pytest -q -m student -o addopts=` xanh cho cả 3 shape
- [ ] `reports/crash.json` có `20/20`; `reports/benchmark.json` đủ 4 shape × 5 seed
- [ ] Commit, rồi ghi hash và run id vào ADR, rồi commit tiếp
- [ ] `python -m lab8.check_submission` ra `0 FAIL`
- [ ] Không commit `traces/`, `*.sqlite`, `.venv/`, `.env`, `student_drop/`
- [ ] Push; repo public hoặc đã mời giảng viên
- [ ] **Cả 4 người** tự nộp link repo trên LMS (ai không nộp thì không có điểm)

## 7. Bonus (tùy chọn, tối đa +10)

Chỉ làm nếu shape chọn đã qua 3 must-pass và đạt ≥ 0.80. Ai xong việc sớm thì nhận, gợi ý là TV3 hoặc TV4. Chọn 1 topic trong [docs/bonus_topics.md](docs/bonus_topics.md), code để trong `src/bonus/`, test trong `src/tests/test_bonus_*.py`.
