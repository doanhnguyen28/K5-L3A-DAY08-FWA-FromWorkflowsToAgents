# Research card

File này nằm cố định ở `report/team/research_card.md`; `python -m lab8.check_submission` đọc cột "Nhóm điền" bằng máy.

Phần này nối tiếp phần mini research ở buổi lý thuyết (slide 62–63). Chọn **một** câu R1–R4, điền 6 dòng, rồi biến nó thành **một ablation** chạy được trong lab: giữ nguyên model (MockLLM), tool, seed, corpus và giá, chỉ thay đổi một biến.

| Câu | Nguồn (thư viện tham khảo, slide 68–69) | Câu hỏi gợi ý cho lab |
| --- | --- | --- |
| R1 · Scaling | Google Research 2026, *Towards a Science of Scaling Agent Systems* | Task claims chủ yếu tuần tự hay song song được? Dự đoán thêm investigator sẽ làm pass rate và cost/success thay đổi thế nào. |
| R2 · Failure taxonomy | MAST, NeurIPS 2025, *Why Do Multi-Agent LLM Systems Fail?* | Các trial fail của swarm (seed 55) thuộc nhóm nào: lỗi giao việc, lệch mục tiêu, hay lỗi kiểm chứng? |
| R3 · Architecture choices | AgentArch, AACL 2026 | Nếu đổi topology mà giữ nguyên mọi thứ khác, biến nào phải cố định để kết luận còn đúng? |
| R4 · Evaluation confounders | EMNLP 2026, *Rethinking Evaluation of MAS Efficiency* | Làm sao chứng minh chênh lệch giữa A/B/C/D là do topology, không phải do prompt, tool hay seed? |

## Phiếu của nhóm

Điền vào cột cuối. Không xóa hai cột đầu.

| Field | Hướng dẫn | Nhóm điền |
| --- | --- | --- |
| CÂU | R1 / R2 / R3 / R4 | R2 · Failure taxonomy |
| SOURCE | Paper/blog, năm, URL, loại bằng chứng (benchmark, production report, blog kinh nghiệm) | Cemri et al., “Why Do Multi-Agent LLM Systems Fail?”, NeurIPS 2025 Datasets and Benchmarks Track, https://proceedings.neurips.cc/paper_files/paper/2025/hash/b1041e52d3be19f0a9bc491657488e4a-Abstract-Datasets_and_Benchmarks_Track.html — nghiên cứu thực nghiệm trên 1.600+ trace từ 7 framework MAS, kèm taxonomy MAST. |
| CLAIM | Một kết luận gốc của nguồn. Không viết rộng hơn phạm vi paper | MAST phân loại 14 mode lỗi thành ba nhóm: lỗi thiết kế hệ thống, lệch căn chỉnh giữa agent, và lỗi xác minh nhiệm vụ. |
| BOUNDARY | Model / dataset / setup giới hạn kết luận đó | Kết quả của paper dựa trên các framework, model và task trong MAST-Data; không suy rộng tỉ lệ lỗi sang lab này. Lab dùng MockLLM seeded và 14 claim public. |
| HYPOTHESIS | Nếu đổi shape A→B (hoặc bật/tắt một thành phần), metric X sẽ đổi theo hướng nào, khoảng bao nhiêu | Trên cùng corpus/seed, workflow sẽ tránh lỗi xác minh của swarm khi ticket mâu thuẫn với order: dự đoán workflow pass 70/70, swarm bỏ lỡ C-002 seed 55. |
| METHOD | Biến giữ cố định: model, tools, seed, corpus, giá, evaluator. Biến duy nhất được thay đổi: … | Chạy benchmark cùng 14 claim, 5 seed, MockLLM, giá, tool và evaluator; biến so sánh là shape (workflow và swarm). Lệnh chuẩn được dùng cho cả bốn shape. Prompt/luồng đọc vốn là một phần của shape nên kết quả là so sánh kiến trúc triển khai, không cô lập riêng topology thuần túy. |
| FAILURE / METRIC | Một lỗi dự kiến và cách đo nó: pass rate, pass^5, variance, cost/success, leak, bypass | Lỗi dự kiến: swarm chấp nhận số ngày do ticket tự nêu mà không xác minh với order (task verification). Đo bằng pass rate và pass^5 theo seed, đối chiếu trial C-002 seed 55. |

## Kết quả ablation

- Lệnh đã chạy (copy nguyên văn): `python -m lab8.benchmark --shapes workflow,single,orchestrator,swarm --cases data/public_claims.jsonl --seeds 11,22,33,44,55 --out reports/benchmark.json`
- Run id / file report: `src/reports/benchmark.json`; trial workflow C-001 seed 11 có run id `R-workflow-C-001-s11`; benchmark gồm 280 trials.
- Kết quả so với hypothesis (đúng / sai / không kết luận được), kèm số liệu: Đúng trên public set. Workflow 70/70 (pass 1.000, pass^5 1.000); swarm 69/70 (pass 0.986, pass^5 0.929). Trial swarm C-002 seed 55 là lỗi duy nhất; workflow 35.23 VND mô phỏng/case thành công so với swarm 49.57.
- Giới hạn: MockLLM không phải model sản xuất, latency là `unavailable`.

Muốn đi xa hơn một ablation để lấy điểm cộng thì xem [docs/bonus_topics.md](../../docs/bonus_topics.md).
