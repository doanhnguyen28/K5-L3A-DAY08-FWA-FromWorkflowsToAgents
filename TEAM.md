# Team

## Thông tin nhóm

- Tên nhóm: FWA
- Lớp: L3A
- Repo nhóm: `K5-L3A-DAY08-FWA-FromWorkflowsToAgents`

## Thành viên

| STT | Họ tên | MSSV | 
| 1 | Đặng Thanh Hải | 2A202603570 | 
| 2 | Nguyễn Đăng Doanh | 2A202603597 |
| 3 | Hoàng Gia Khiêm | 2A202603540 |
| 4 | Đoàn Văn Tú | 2A202603595 | 

## Bảng đóng góp

`python -m lab8.check_submission` đọc bảng này bằng máy: giữ nguyên tiêu đề `## Bảng đóng góp` và các cột. Mỗi người một dòng: commit có nội dung và ít nhất một test đã thêm hoặc sửa.

| Người | Vai | Commit | Test đã thêm hoặc sửa |
| --- | --- | --- | --- |
| Đặng Thanh Hải (2A202603570) | TV1: Workflow + Integration | `a3409b4` | `src/tests/test_team_workflow.py` (trace, policy ticket, idempotency, T14) |
| Nguyễn Đăng Doanh (2A202603597) | TV2: Single agent: `src/lab8/shapes/single.py`, `group_report.md` mục 3B và 5 | `8742c52` feat(single): ReAct agent tối đa 8 bước, chỉ dùng tool đọc; code tính quote, host ghi refund | `src/tests/test_team_single.py` (35 test: không tin số ngày trễ trong ticket, ≤ 8 bước, không chọn tool ghi, T14 truyền quote đầy đủ, trace không lộ secret/PII) |
| Hoàng Gia Khiêm (2A202603540) | TV3: Orchestrator + Handoff | `c3eef95` | `src/tests/test_team_handoff.py` (handoff allowlist, trace/stdout an toàn, crash resume) |
| Đoàn Văn Tú (2A202603595) | TV4: Ledger + Evaluation, benchmark và báo cáo đánh giá |  | `src/tests/test_team_policy.py` (21 test: approval, order cap, idempotency, T14, crash resume); `src/reports/benchmark.json` (280 trial, 4 shape × 14 claim × 5 seed) |


