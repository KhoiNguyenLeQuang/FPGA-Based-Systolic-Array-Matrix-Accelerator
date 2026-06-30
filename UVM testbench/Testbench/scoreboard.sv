// Lớp này kế thừa từ uvm_scoreboard, chịu trách nhiệm chấm điểm đúng/sai cho chip
class gemm_scoreboard extends uvm_scoreboard;
    // Đăng ký với hệ thống UVM factory
    `uvm_component_utils(gemm_scoreboard)

    // Hai chiếc giỏ FIFO (First-In, First-Out) xếp hàng để chứa dữ liệu:
    uvm_tlm_analysis_fifo #(gemm_seq_item) exp_fifo; // Giỏ chứa đáp án chuẩn (Mô hình toán học)
    uvm_tlm_analysis_fifo #(gemm_seq_item) act_fifo; // Giỏ chứa kết quả thật (Chip nhả ra)

    // Interface dùng để theo dõi chân Reset của phần cứng
    virtual gemm_if vif;

    function new(string name = "gemm_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // BUILD PHASE: Khởi tạo các giỏ FIFO và lấy dây cáp kết nối (vif)
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_fifo = new("exp_fifo", this);
        act_fifo = new("act_fifo", this);

        if (!uvm_config_db#(virtual gemm_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface 'vif' was not found in uvm_config_db!")
        end
    endfunction

    // RUN PHASE: CƠ CHẾ CHẤM ĐIỂM VÀ XỬ LÝ RESET SỰ KIỆN
    virtual task run_phase(uvm_phase phase);
        gemm_seq_item exp_item;
        gemm_seq_item act_item;
        bit error_found;

        // Vòng lặp bao quát toàn bộ quá trình mô phỏng
        forever begin
            
            // THUẬT TOÁN SONG SONG (fork ... join_any):
            // Nhánh này dùng để xử lý kịch bản "Đang chấm bài thì đột ngột bị dập Reset"
            fork
                // NHÁNH 1: Chờ dữ liệu về và tiến hành chấm bài
                begin
                    forever begin
                        // Lệnh .get() sẽ bắt Scoreboard ngồi đợi. Khi nào CẢ HAI giỏ exp_fifo và act_fifo đều có bài, nó mới đồng thời bốc ra để chấm.
                        exp_fifo.get(exp_item);
                        act_fifo.get(act_item);

                        // Đợi 1 picosecond (mẹo nhỏ để dữ liệu từ phần cứng ổn định định thời, 
                        // tránh hiện tượng chạy đua delta-cycle trong mô phỏng).
                        #1ps; 

                        // Nếu trong lúc này mạch đang bị Reset thì bỏ qua không chấm
                        if (vif.rst === 1'b1) begin
                            continue; 
                        end

                        error_found = 0;

                        // So sánh ma trận NxN (4x4): Duyệt qua từng ô một!
                        for (int i = 0; i < N; i++) begin
                            for (int j = 0; j < N; j++) begin
                                // Nếu kết quả Thật (act) KHÁC kết quả Chuẩn (exp)
                                if (act_item.act_matrix_C[i][j] !== exp_item.exp_matrix_C[i][j]) begin
                                    // Thổi còi báo lỗi ngay lập tức, in rõ vị trí hàng/cột bị sai!
                                    `uvm_error("MISMATCH", $sformatf("Matrix error at [%0d][%0d]! Exp: %0d, Act: %0d", 
                                               i, j, exp_item.exp_matrix_C[i][j], act_item.act_matrix_C[i][j]))
                                    error_found = 1;
                                end
                            end
                        end

                        // Nếu kiểm tra hết 16 ô mà không có lỗi nào
                        if (!error_found) begin
                            `uvm_info("PASS", $sformatf(">>> SUCCESS: Full %0dx%0d hardware matrix matches reference calculation model safely!", N, N), UVM_LOW)
                        end
                    end
                end

                // NHÁNH 2: Thám tử đứng rình xem khi nào nút Reset bị bấm
                begin
                    @(posedge vif.rst); // Khi chân Reset chuyển từ 0 lên 1
                end
            join_any // Chỉ cần 1 trong 2 nhánh hoàn thành thì dừng khối chập này.
            
            // Nếu Nhánh 2 chạy trước (tức là phát hiện nút Reset bị bấm) -> Giết chết Nhánh 1 đang chấm dở
            disable fork;

            // XỬ LÝ KHI BỊ RESET:
            // Khi chip bị ép nút reset, toàn bộ dữ liệu đang tính toán dở trong các hàng 
            // của Systolic Array sẽ bị xóa sạch. Do đó, Scoreboard cũng phải đổ sạch (flush) 
            // dữ liệu cũ trong 2 giỏ FIFO đi, để tránh việc lấy rác cũ ra chấm cho ma trận mới.
            `uvm_info("RESET_DETECTED", "Hardware reset detected! Flushing scoreboard FIFOs.", UVM_LOW)
            exp_fifo.flush();
            act_fifo.flush();

            // Đợi đến khi nút Reset được nhả ra (từ 1 về 0)
            @(negedge vif.rst);
            `uvm_info("RESET_RELEASED", "Hardware reset released. Performing final FIFO flush.", UVM_LOW)
            exp_fifo.flush();
            act_fifo.flush(); // Dọn dẹp sạch sẽ một lần nữa để sẵn sàng cho hiệp đấu mới.
        end
    endtask
endclass
