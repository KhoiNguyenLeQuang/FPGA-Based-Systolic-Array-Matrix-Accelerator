// Lớp này kế thừa từ uvm_env, đóng vai trò là chiếc "hộp chứa" lớn nhất (nằm ngay dưới Test)
class gemm_env extends uvm_env;
    // Đăng ký với hệ thống UVM factory
    `uvm_component_utils(gemm_env)

    // Khai báo các thiết bị sẽ làm việc trong phòng này:
    gemm_agent      agent;      // Agent: Chứa Driver và Monitor 
    gemm_scoreboard scoreboard; // Scoreboard: Người chấm điểm đúng/sai
    gemm_coverage   coverage;   // Coverage: kiểm tra độ phủ

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // BUILD PHASE
    // Chạy từ trên xuống dưới trước khi mô phỏng bắt đầu
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Dùng UVM factory để chính thức tạo ra (cấp phát bộ nhớ) cho 3 thành phần này.
        // Chữ "this" ở cuối báo cho hệ thống biết: "Tui (env) chính là sếp/cha của tụi nó".
        agent      = gemm_agent::type_id::create("agent", this);
        scoreboard = gemm_scoreboard::type_id::create("scoreboard", this);
        coverage   = gemm_coverage::type_id::create("coverage", this); 
    endfunction

    // CONNECT PHASE
    // Chạy ngay sau khi Build Phase hoàn tất. Dùng để nối các cổng thông tin (port) lại với nhau.
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // 1. Nối Driver với Scoreboard (Gửi Đáp Án)
        // Lấy cổng phát (drv_ap) của Driver cắm vào cổng nhận (analysis_export) của giỏ exp_fifo.
        // Ý nghĩa: Khi Driver bắt đầu gửi 1 ma trận, nó gửi luôn "bản sao kèm đáp án đúng" cho Scoreboard giữ giùm.
        agent.driver.drv_ap.connect(scoreboard.exp_fifo.analysis_export);
        
        // 2. Nối Monitor với Scoreboard (Gửi Bài Làm Thực Tế)
        // Lấy cổng phát (mon_ap) của Monitor cắm vào cổng nhận của giỏ act_fifo.
        // Ý nghĩa: Khi Monitor đọc được kết quả tính toán từ phần cứng nhả ra, nó nộp bài cho Scoreboard.
        // Scoreboard sẽ lôi "đáp án" từ giỏ 1 và "bài làm" từ giỏ 2 ra để so sánh.
        agent.monitor.mon_ap.connect(scoreboard.act_fifo.analysis_export);
        
        // 3. Nối Driver với Coverage (Gửi Dữ Liệu Đã Nạp)
        // Lấy cổng phát của Driver cắm vào bộ đếm Coverage.
        // Ý nghĩa: Báo cho ông cầm sổ chấm công biết là "Tôi vừa nạp tổ hợp số này vào phần cứng nhé, 
        // ông đánh dấu tick vào sổ giùm tôi".
        agent.driver.drv_ap.connect(coverage.analysis_export); 
    endfunction
endclass
