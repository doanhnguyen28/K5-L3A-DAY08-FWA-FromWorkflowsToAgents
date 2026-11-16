# Báo cáo cá nhân — 2A202603597_NguyenDangDoanh

## 1. Thông tin thành viên

- Họ tên: Nguyễn Đăng Doanh
- MSSV: 2A202603597
- Email: 26ai.doanhnd@vinuni.edu.vn
- GitHub: doanhnguyen28

## 2. Phần việc phụ trách

- Shape B `src/lab8/shapes/single.py`: một agent ReAct chạy tối đa 8 bước, chỉ dùng tool đọc. Code của shape tính tiền và gọi host.
- Test nhóm cho shape B: `src/tests/test_team_single.py`.
- Báo cáo nhóm `report/team/group_report.md`: mục 3B (Single agent) và phần TV2 trong mục 5 (Khó khăn và cách xử lý).

## 3. Đóng góp cụ thể

**Commit chính:** `8742c52` "submit tv2" trên `main`, gồm `src/lab8/shapes/single.py` và `src/tests/test_team_single.py`.

**Shape B `single.py`:**

- Hàm `decide` là chính sách của agent. Nó chỉ chọn tool đọc, theo thứ tự `get_claim_view` → `lookup_order` → `lookup_refund_history`, rồi trả `final`. Không có claim thì trả `failed`, thiếu `order_id` thì `needs_info`, không thấy đơn hoặc sai chủ thì `escalated`.
- Chạy vòng lặp bằng `lab8.runtime.run_react(max_steps=8)`. Nếu model chọn tool ghi thì `dispatch` ném `ToolRejected`, shape bắt lỗi này và trả `failed` để `run_claim` không ném exception.
- Sau vòng lặp, code tính quote bằng `compute_compensation` từ order row trong DB rồi gọi `durability.issue_refund` với quote đầy đủ và `crash_at`. Shape không bắt `InjectedCrash`: chỉ ghi event `crash` vào trace rồi `raise` lại.
- Phần sau khi có quote (gán `denied` / `failed` / `resolved`, trace `issue_refund`, hàm `done()`) viết giống workflow của TV1, để khi benchmark thì khác biệt giữa A và B chỉ nằm ở phần đọc do agent điều khiển.

**Các quyết định kỹ thuật:**

| Quyết định | Lý do |
| --- | --- |
| `decide` là closure giữ một dict `memory` theo tên tool | `run_react` chỉ đưa lại kết quả của tool vừa gọi. Không có `memory` thì đến bước thứ ba agent không còn thấy dòng claim |
| Agent đọc `lookup_refund_history` nhưng không trừ số đã hoàn vào quote | Host tự áp trần theo đơn. Nếu shape trừ trước thì bị trừ hai lần: T14 sẽ ra 90.000 thay vì 120.000 |
| Agent không gọi `get_clause` | `get_clause` trả cả policy cũ (`SHIP-LATE-OLD`) và policy tương lai. `compute_compensation` đã chỉ dùng policy `is_current` có `effective_date <= 2026-11-15` |
| Mỗi bước gọi MockLLM một lần (`purpose="react"`), prompt chỉ có `claim_id` và số bước | Budget tính đúng cost của một agent để so sánh với workflow. Prompt không chứa ticket, order row hay số tiền |
| Trace chỉ ghi tên tool, trạng thái và các số tổng hợp | Trace là ranh giới bảo mật. Không ghi ticket, kết quả thô của tool, `memory`, claim row hay order row |

**Test đã thêm:** `src/tests/test_team_single.py`, 35 test, chạy trong cổng host `pytest -q`:

- `test_agent_ignores_delay_written_in_ticket`: C-002 có ticket ghi "trễ 5 ngày" nhưng DB ghi 2 ngày. Kết quả phải là `denied` và không ghi ledger, ở cả 5 seed. Đây đúng là chỗ swarm tham chiếu sai ở seed 55.
- `test_agent_stays_under_step_cap_and_counts_model_calls`: chạy cả 14 claim public, agent không vượt 8 bước và mỗi bước đều được tính vào Budget.
- `test_agent_never_picks_a_write_tool`: agent chỉ chọn trong ba tool đọc.
- `test_t14_full_quote_even_after_reading_refund_history`: `proposal_amount = 150000`, ledger ghi 120.000.
- `test_trace_has_no_secret_or_pii`: quét trace của cả 14 claim để chắc không có `CANARY_`, SĐT, địa chỉ, tên hàng, ghi chú nội bộ hay ticket.

## 4. Bằng chứng

Các lệnh dưới đây chạy trong `src/` trên Windows 10, Python 3.11.9:

| Lệnh | Kết quả |
| --- | --- |
| `python -m lab8.smoke` | `lab8.smoke pass` |
| `python -m pytest -q` | `112 passed, 248 deselected` |
| `python -m pytest -q -m student -o addopts= -k "single]"` | `62 passed` (T01–T14 × 5 seed, T11, T12) |
| `python -m pytest -q tests/test_team_single.py` | `35 passed` |

- Commit: `8742c52` (https://github.com/doanhnguyen28/K5-L3A-DAY08-FWA-FromWorkflowsToAgents/commit/8742c52)

- Benchmark của shape single (pass rate, cost/success, mean steps): lấy từ `src/reports/benchmark.json`, run id `<run_id>`, sau khi TV4 chạy benchmark.

## 5. Công cụ AI đã dùng

**Công cụ:** Claude Code (trợ lý AI chạy trong VS Code).

**Dùng vào việc:**

- Chẩn đoán lỗi `git clone` (`Failed to connect to github.com:443`). AI kiểm tra proxy, `curl` và `git ls-remote`, và kết luận đây là lỗi mạng tạm thời.
- Đọc đề và chia việc cho nhóm 4 người.
- Gợi ý `single.py`, `test_team_single.py` và mục 3B trong báo cáo nhóm, dựa trên `runtime.py`, `tools.py`, `swarm_reference.py`.

**Cách tôi tự kiểm tra:**

- Chạy cổng host, bộ test student của single và test team như ở mục 4. Chỉ commit khi cả ba đều xanh.
- Tự đọc `run_react` trong `runtime.py` để xác nhận nó chỉ trả kết quả của tool cuối, và đó là lý do cần `memory`.
- Đối chiếu các nhánh trả về với bảng output trong `docs/contracts.md` và luật trong `docs/business_rules.md`, đặc biệt là T13, T14 (quote đầy đủ) và T12 (không bắt `InjectedCrash`).
- Không dùng AI để tạo số liệu benchmark, run id hay commit hash. Các số đó lấy từ file report do công cụ sinh ra.

## 6. Tự đánh giá

- **Đã làm được:** shape B qua đủ 62/62 test student và không làm đỏ cổng host. Ranh giới code / model rõ ràng: model chỉ chọn tool đọc, tiền do code tính, chỉ host được ghi ledger. Trace không lộ secret hay PII trên bộ public.
- **Hiểu được:**
  - Vì sao phải truyền quote đầy đủ vào `issue_refund`.
  - Vì sao quote > 0 bị từ chối vẫn phải gọi host để có audit `policy_denied`.
  - Vì sao không được bắt `InjectedCrash`.
  - Vì sao chữ trong ticket là dữ liệu chứ không phải lệnh.
- **Hạn chế:**
  - `decide` hiện là một chính sách cố định viết bằng code. MockLLM không thật sự "suy nghĩ", nên trên bộ public, single cho kết quả giống workflow và chỉ tốn thêm model call. Với model thật, thứ tự gọi tool có thể dao động, và lúc đó giới hạn 8 bước cùng việc chỉ cho tool đọc mới thật sự phát huy tác dụng.
  - Shape chưa được kiểm tra trên bộ hidden.
- **Nếu làm lại:** sẽ viết test cho nhánh `step_cap` và `ToolRejected` bằng cách thay `decide` bằng một chính sách cố ý chọn sai, để chứng minh hai nhánh an toàn này hoạt động.
