# Decision record

Shape được chọn là kiến trúc nhóm đề xuất từ benchmark public; shape này cần được xác nhận trên hidden set.

- Shape chọn: workflow
- Commit hash:
- Run id dẫn chứng: R-workflow-C-001-s11 (`src/reports/benchmark.json`)
- Pass rate / pass^5 / seed min-max / variance: 1.000 / 1.000 / 1.000–1.000 / 0.000000 (70 trials, public)
- Cost per success (mô phỏng, VND): 35.23
- Crash safety: 20/20 (`src/reports/crash.json`)
- Secret leak / approval bypass: 0 leak trong 70 trial workflow theo evaluator; 0 bypass trong test approval và public matrix


## Vì sao shape này

Workflow là lựa chọn phù hợp nhất trên public set: cả workflow, single và orchestrator đều đạt 70/70, pass^5 = 1.000 và variance = 0, nhưng workflow có cost/success thấp nhất (35.23 VND mô phỏng, so với 45.31 của single và 54.28 của orchestrator). Workflow cũng thấp hơn swarm (49.57), vốn chỉ đạt pass rate 0.986 và pass^5 0.929 do C-002 seed 55. Đây là lựa chọn ít tự chủ nhất trong các shape nhóm tự viết, đồng thời đạt đủ yêu cầu trên corpus đã chạy.

## Có đáng đổi lấy multi-agent không

Không đổi sang multi-agent chỉ vì số bước thấp hơn; trên benchmark này các shape tự viết cùng pass rate, còn chi phí workflow thấp hơn. Quyết định sẽ được xem lại nếu hidden set cho thấy workflow dưới ngưỡng 0.75 hoặc nếu cùng một benchmark có kiểm soát cho thấy shape khác cải thiện đáng kể pass rate mà vẫn giữ các must-pass và mức cost chấp nhận được.

## Trace và bằng chứng

Trace các shape ghi event quyết định, bước đọc/handoff, quote, kết quả host và crash khi có. Trace không ghi ticket, secret/header, claim row hay order row thô, SĐT, địa chỉ, tên hàng hoặc `internal_note`. `test_team_workflow.py`, `test_team_single.py` và `test_team_handoff.py` quét trace/stdout cho mọi claim public; `test_team_policy.py` kiểm tra approval và ledger trên ba shape. Benchmark cũng kiểm tra trace contract trên từng trial.

## Giới hạn

Benchmark dùng MockLLM seeded và 14 claim public; giá là mô phỏng, latency không được đo (`unavailable`). Chưa có kết quả hidden self-check trong repo, nên quyết định workflow cần được xác nhận trên hidden set.
