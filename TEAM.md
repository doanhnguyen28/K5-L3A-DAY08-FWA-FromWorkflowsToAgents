# Team

## Thông tin nhóm

- Tên nhóm: FWA
- Lớp: L3A
- Repo nhóm: `K5-L3A-DAY08-FWA-FromWorkflowsToAgents` 
- URL repo, nhánh nộp, commit chốt:

## Thành viên

| STT | Họ tên | MSSV | Email | GitHub | Vai trò |
| --: | ------ | ---- | ----- | ------ | ------- |
|   1 | Đặng Thanh Hải | 2A202603570|      |   HaiDang0502    |Shape A `workflow.py`, tạo repo, merge PR, chạy `check_submission        |
|   2 | Nguyễn Đăng Doanh | 2A202603597|      | doanhnguyen28  | Shape B `single.py` (ReAct ≤ 8 bước)     |
|   3 | Hoàng Gia Khiêm | 2A202603540|      |       |Shape C `orchestrator.py`, handoff an toàn, rà secret/PII trong trace   |
|   4 | Đoàn Văn Tú | 2A202603595|      |       |Crash suite, idempotency, policy test, benchmark, ADR, research card       |

Gợi ý chia vai:

- Nhóm 6 người: integration; workflow; single agent; orchestrator; ledger/policy/crash; eval/report.
- Nhóm 4 người: workflow + integration; single; orchestrator + handoff; ledger + evaluation.

## Bảng đóng góp

`python -m lab8.check_submission` đọc bảng này bằng máy: giữ nguyên tiêu đề `## Bảng đóng góp` và các cột. Mỗi người một dòng: commit có nội dung và ít nhất một test đã thêm hoặc sửa.

| Người | Vai | Commit | Test đã thêm hoặc sửa |
| --- | --- | --- | --- |
| Nguyễn Đăng Doanh (2A202603597) | TV2: Single agent: `src/lab8/shapes/single.py`, `group_report.md` mục 3B và 5 | `8742c52` feat(single): ReAct agent tối đa 8 bước, chỉ dùng tool đọc; code tính quote, host ghi refund | `src/tests/test_team_single.py` (35 test: không tin số ngày trễ trong ticket, ≤ 8 bước, không chọn tool ghi, T14 truyền quote đầy đủ, trace không lộ secret/PII) |
| Đặng Thanh Hải (2A202603570) | Shape A workflow.py, tạo repo, merge PR, chạy `check_submission`, `group_report.md` mục 3 | `8742c52` feat(single): ReAct agent tối đa 8 bước, chỉ dùng tool đọc; code tính quote, host ghi refund | `src/tests/test_team_workflow.py` (23 test, chạy trong cổng host pytest -q) |

## Cá nhân

Mỗi thành viên đồng thời tạo một báo cáo riêng trong `report/` theo dạng:

```text
report/team/MSSV_HoTen.md
```

Ví dụ: `report/team/20241234_NguyenVanAn.md`.

Sao chép mục dưới đây cho từng thành viên.

## MSSV_HoTen

### Phần việc phụ trách

-

### Đóng góp cụ thể

-

### Bằng chứng

-
