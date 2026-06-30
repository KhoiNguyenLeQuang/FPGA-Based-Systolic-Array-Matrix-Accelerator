// Lớp này kế thừa từ uvm_monitor, chuyên làm nhiệm vụ theo dõi tín hiệu
class gemm_monitor extends uvm_monitor;
    // Đăng ký với hệ thống UVM factory
    `uvm_component_utils(gemm_monitor)

    // Sợi cáp (Virtual interface) để Monitor có thể xem vào các chân của phần cứng
    virtual gemm_if #(.N(N), .WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)) vif;
    
    // Cổng phát thanh (Analysis port): Dùng để gửi kết quả bắt được cho Scoreboard và Coverage
    uvm_analysis_port #(gemm_seq_item) mon_ap; 

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // BUILD PHASE: Xin cấp sợi cáp (vif) từ database và tạo cổng phát thanh
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_ap = new("mon_ap", this);
        if (!uvm_config_db#(virtual gemm_if #(.N(N), .WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)))::get(this, "", "vif", vif))
            `uvm_fatal("VIF", "Monitor could not find the virtual interface!")
    endfunction

    // RUN PHASE: Vòng lặp quan sát không ngừng nghỉ
    task run_phase(uvm_phase phase);
        gemm_seq_item item;
        
        // Đợi hệ thống khởi động xong (reset xong) mới bắt đầu làm việc
        @(negedge vif.rst);
        @(posedge vif.clk);
        
        forever begin
            // BẮT ĐẦU PHÁT HIỆN GIAO DỊCH:
            // Nếu thấy dữ liệu ở A hoặc B khác 0, nghĩa là Driver bắt đầu nạp ma trận vào
            if (vif.a_in_bus !== '0 || vif.b_in_bus !== '0) begin              
                
                // CHỜ ĐỢI LATENCY (ĐỘ TRỄ PHẦN CỨNG):
                // Theo kiến trúc Systolic Array NxN, từ lúc con số đầu tiên đi vào, 
                // phải mất đúng (3*N - 2) chu kỳ xung nhịp thì phần tử cuối cùng (góc dưới cùng bên phải) 
                // mới tính toán xong và nhả kết quả ra. (Với N=4 thì đợi 10 chu kỳ).
                repeat(3*N - 2) @(posedge vif.clk); 
                
                // Tạo một item để ghi kết quả
                item = gemm_seq_item::type_id::create("item");
                
                // UN-FLATTEN (Giải nén dữ liệu):
                // Cắt sợi cáp khổng lồ 512-bit (c_out_bus) thành 16 khúc, 
                // mỗi khúc 32-bit (ACC_WIDTH), rồi nhét lại vào ma trận 4x4 (act_matrix_C)
                for (int i = 0; i < N; i++) begin
                    for (int j = 0; j < N; j++) begin
                        // Tính toán vị trí cắt cáp (bus_index)
                        int bus_index = (i * N) + j;
                        item.act_matrix_C[i][j] = vif.c_out_bus[(bus_index * ACC_WIDTH) +: ACC_WIDTH];
                    end
                end
                
                // Báo qua loa phóng thanh (mon_ap) để gửi đáp án thực tế cho Scoreboard
                mon_ap.write(item);
                
                // Cooldown:
                // Đợi 4 chu kỳ clock để bỏ qua giai đoạn Driver đang nháy Reset (xóa bộ nhớ).
                // Nếu không đợi, Monitor có thể vô tình bắt nhầm lại dữ liệu cũ hoặc bắt nhầm số 0.
                repeat(4) @(posedge vif.clk);
            end else begin
                // Nếu không có dữ liệu vào (cả A và B bằng 0), thì chỉ đứng nhìn và qua nhịp clock tiếp theo
                @(posedge vif.clk);
            end
        end
    endtask
endclass
