# Báo cáo cá nhân — <MSSV>_<HoTen>

## 1. Thông tin thành viên

- Họ tên: Hoàng Gia Khiêm   
- MSSV: 2A202603540
- Email: khiemhg0709@gmail.com  
- GitHub: khiemhg79

## 2. Phần việc phụ trách

Vai **TV3: Orchestrator + Handoff**.

- Shape C: `src/lab8/shapes/orchestrator.py` (orchestrator + investigator chỉ đọc).
- Handoff an toàn: dựng bằng `lab8.handoff.make_handoff`, allowlist field và facts, tool chỉ đọc.
- Rà secret/PII trong trace của cả 3 shape nhóm viết (workflow, single, orchestrator) ở CP4.
- Báo cáo: `decision_adr.md` mục "Trace và bằng chứng", `group_report.md` mục 3C.

## 3. Đóng góp cụ thể

**Commit chính:**
- `<hash>`: TV3: orchestrator shape + safe handoff, test_team_handoff (CP4 trace audit)
- `<hash>`: TV3: phan cong + ADR muc Trace va bang chung

**Code (`orchestrator.py`):**
- Orchestrator đọc claim qua `get_claim_view`, xử lý sớm các nhánh `failed` (không có claim) và `needs_info` (thiếu `order_id`).
- Dựng handoff với task `investigate_order_and_refund_history`, facts rỗng, và 3 tool đọc: `get_claim_view`, `lookup_order`, `lookup_refund_history`.
- Investigator chạy qua `run_readonly_investigators` (dispatch `worker=True`). Đơn không thấy hoặc sai chủ thì ra `escalated`.
- Orchestrator tự tính quote bằng `compute_compensation` từ order view, rồi gọi `durability.issue_refund` với quote đầy đủ và `crash_at`. `InjectedCrash` không bị bắt: shape ghi trace rồi `raise`.
- Trace chỉ ghi handoff đã sanitize và báo cáo investigator đã lọc qua `FACT_KEYS`.

**Test (`src/tests/test_team_handoff.py`, 66 test):**
- Facts của handoff không chứa `parent_secret`, header, ticket hay PII, kể cả khi truyền nguyên claim row + order row vào.
- Tool của investigator chỉ là tool đọc; `make_handoff` từ chối `issue_refund` và `append_audit`.
- Trace orchestrator của 14 claim public không chứa `CANARY_SECRET_` hay PII. Event `handoff` chỉ có field trong `ALLOWED_FIELDS`.
- Orchestrator bỏ qua số ngày trễ ghi trong ticket (C-002 vẫn ra `denied`).
- Crash không bị nuốt; resume xong chỉ có 1 refund.
- CP4 cho cả 3 shape: quét mọi file `<run_id>*`, stdout/stderr và `RunResult`; kiểm tra bằng AST rằng 3 file shape không có `print()`.

**Quyết định kỹ thuật:**
1. **Không giao `compute_compensation` cho investigator**, dù tool này nằm trong `READONLY_TOOLS`. Tiền phải do orchestrator (code) tính, để worker không có vai trò gì trong quyết định số tiền.
2. **Facts lúc giao việc để rỗng.** Investigator chỉ cần `claim_id` và tự tra qua tool đọc, nên không có lý do gì để đưa dữ liệu của parent sang worker.
3. **Kết quả investigator đi qua lại allowlist (`FACT_KEYS`) trước khi ghi trace**, thay vì ghi nguyên order view. Nhờ vậy trace của orchestrator không phụ thuộc vào việc `lookup_order` sau này có trả thêm field hay không.
4. **`lookup_refund_history` chỉ để ghi trace**, không dùng để tự trừ tiền, vì host đã tự trừ (T13, T14). Tự trừ thêm thì T14 ra 90.000 thay vì 120.000.
5. **MockLLM chỉ nhận tên task và status.** Model không thấy ticket, order row hay số tiền, vì tóm tắt bằng LLM không phải là redaction.

## 4. Bằng chứng

- Code: `src/lab8/shapes/orchestrator.py`; test: `src/tests/test_team_handoff.py`.
- Link commit: `https://github.com/<owner>/<repo>/commit/<hash>`
- Kết quả chạy trong `src/`:
  - `python -m pytest -q -m student -o addopts= -k orchestrator` → **62 passed**
  - `python -m pytest -q -m student -o addopts=` → **248 passed**
  - `python -m pytest -q tests/test_team_handoff.py` → **66 passed**
  - `python -m pytest -q` → **178 passed**
- Rà CP4 bằng PowerShell (`ra_an_toan.ps1`): quét **186** file trace của 3 shape → **0 file vi phạm**, **không có `print()`** trong 3 file shape.
- Trace mẫu: `src/traces/R-orchestrator-C-010-s11.json`. File chỉ có các event `claim`, `handoff`, `investigator_report`, `quote`, `issue_refund`, `decision`, không có ticket, SĐT hay canary. Trace không được commit, chạy lại test để sinh ra.
- Báo cáo: `report/team/decision_adr.md` mục "Trace và bằng chứng"; `report/team/group_report.md` mục 3C; `PHAN_CONG_TV3.md`.

## 5. Công cụ AI đã dùng

- **Claude (Anthropic)**, dùng để:
  - đọc `handoff.py`, `runtime.py`, `docs/contracts.md` và các shape có sẵn;
  - viết bản nháp `orchestrator.py` theo khung của workflow;
  - viết bản nháp `test_team_handoff.py` và script PowerShell rà trace;
  - soạn nháp mục ADR, group report và báo cáo này.
- **Cách tự kiểm tra:**
  - Tự chạy lại toàn bộ lệnh ở mục 4 trên máy mình và đối chiếu số passed.
  - Chạy script PowerShell trên `src/traces/` sau khi sinh trace; tự mở trace mẫu của orchestrator để xem không có ticket, SĐT hay canary.
  - Đọc lại code để chắc rằng `crash_at` được truyền vào `issue_refund`, `InjectedCrash` không bị bắt, và quote truyền vào là quote đầy đủ.
  - Số liệu trong báo cáo lấy từ output thật, không lấy từ AI. Có một con số AI đoán sai (dự kiến 168 file trace, thực tế là 186), mình đã sửa theo output thật.

## 6. Tự đánh giá

- **Đã làm được:**
  - Orchestrator đạt 62/62 test public của shape C.
  - Handoff dùng allowlist trong code và chỉ giao tool đọc.
  - Trace của cả 3 shape sạch secret/PII, có test tự động để giữ như vậy khi nhóm sửa code sau này.
- **Hạn chế:**
  - Rà an toàn mới chạy trên 14 claim public; hidden set có thể có dạng dữ liệu khác.
  - Test PII dựa trên danh sách giá trị lấy từ `public_world_state.json`, nên không bắt được PII ở dạng khác (ví dụ SĐT viết khác định dạng).
  - Orchestrator đắt hơn workflow một model call (`plan`) mà không có lợi ích về độ đúng trên bộ public. Điều này khớp với việc chọn shape ít tự chủ nhất trong ADR.
- **Nếu có thêm thời gian:**
  - Thêm scanner dạng regex (SĐT, chuỗi có dạng secret) bên cạnh danh sách giá trị cố định.
  - Cho phép chạy nhiều investigator song song, mỗi investigator một tool, để đo xem cost và variance thay đổi thế nào.