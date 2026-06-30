// Lớp này kế thừa từ uvm_driver, chuyên dùng để xử lý gói dữ liệu gemm_seq_item
class gemm_driver extends uvm_driver #(gemm_seq_item);
    // Đăng ký với UVM factory
    `uvm_component_utils(gemm_driver)

    // Virtual interface (vif): Đây là "sợi cáp" kết nối giữa thế giới phần mềm (UVM) 
    // và thế giới phần cứng (các chân tín hiệu của RTL).
    virtual gemm_if #(.N(N), .WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)) vif;
    
    // Cổng phân tích (Analysis port): Dùng để gửi bản sao của gói dữ liệu cho Scoreboard
    uvm_analysis_port #(gemm_seq_item) drv_ap; 

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // BUILD PHASE: Lấy sợi cáp (vif) từ database của hệ thống để chuẩn bị kết nối
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_ap = new("drv_ap", this);
        if (!uvm_config_db#(virtual gemm_if #(.N(N), .WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH)))::get(this, "", "vif", vif))
            `uvm_fatal("VIF", "Driver could not find the virtual interface!")
    endfunction

    // RUN PHASE: Vòng lặp làm việc không ngừng nghỉ của Driver
    task run_phase(uvm_phase phase);
        gemm_seq_item item;
        
        // Khởi tạo ban đầu: Đặt tín hiệu reset và xóa sạch các đường truyền (bus)
        vif.rst <= 1; 
        vif.a_in_bus <= 0;
        vif.b_in_bus <= 0;
        @(negedge vif.rst); // Chờ đến khi hết reset
        @(posedge vif.clk); // Canh đều vào sườn lên của clock

        forever begin
            // 1. Nhận lệnh: Lấy gói dữ liệu tiếp theo từ Sequencer
            seq_item_port.get_next_item(item);
            
            // 2. Tính trước kết quả đúng và báo cho Scoreboard biết chuẩn bị chấm điểm
            item.compute_expected(); 
            drv_ap.write(item);    

            // 3. Bơm dữ liệu: Thực sự điều khiển các chân tín hiệu phần cứng (gọi hàm bên dưới)
            drive_transaction(item);
            
            // 4. Nháy Reset: Xóa sạch bộ nhớ phần cứng (các Processing Elements) 
            // để chuẩn bị đón ma trận tiếp theo. Dùng <= để an toàn về timing.
            vif.rst <= 1;
            repeat(2) @(posedge vif.clk);
            vif.rst <= 0;
            repeat(2) @(posedge vif.clk); 
            
            // 5. Báo cáo hoàn thành: Báo cho Sequencer biết là "Tôi đã giao hàng xong, đưa gói tiếp theo đây!"
            seq_item_port.item_done();
        end
    endtask

    // HÀM BƠM DỮ LIỆU (THEO CẤU TRÚC SYSTOLIC ARRAY)
    task drive_transaction(gemm_seq_item item);
        int col_idx;   
        logic [N*WIDTH-1:0] local_a_bus; // Chứa dữ liệu của cột A để đẩy vào bus
        logic [N*WIDTH-1:0] local_b_bus; // Chứa dữ liệu của hàng B để đẩy vào bus

        // Với cấu trúc mảng Systolic Array NxN, ta cần đẩy dữ liệu theo hình bình hành (data skewing).
        // Tổng thời gian đẩy hết ma trận cần (2*N - 1) chu kỳ clock.
        for (int t = 0; t < 2*N-1; t++) begin
            
            // Quét qua từng làn (lane/row) của phần cứng
            for (int lane = 0; lane < N; lane++) begin
                
                // CÔNG THỨC QUAN TRỌNG: Tạo độ trễ hình chéo (skew)
                // Ví dụ: Làn 0 nhận dữ liệu từ nhịp t=0. Nhưng Làn 1 phải đợi đến nhịp t=1 mới được nhận.
                col_idx = t - lane;  
                
                // Nếu chỉ số hợp lệ (nằm trong phạm vi ma trận)
                if (col_idx >= 0 && col_idx < N) begin
                    // Đẩy dữ liệu thật vào làn tương ứng
                    local_a_bus[(lane*WIDTH) +: WIDTH] = item.matrix_A[lane][col_idx];
                    local_b_bus[(lane*WIDTH) +: WIDTH] = item.matrix_B[col_idx][lane];
                end else begin
                    // Nếu chưa tới lượt hoặc đã đẩy xong thì nhét số 0 vào (padding)
                    local_a_bus[(lane*WIDTH) +: WIDTH] = 0;
                    local_b_bus[(lane*WIDTH) +: WIDTH] = 0;
                end
            end
            
            // Đưa dữ liệu ra chân tín hiệu (vif) và chờ 1 nhịp clock
            vif.a_in_bus <= local_a_bus;
            vif.b_in_bus <= local_b_bus;
            @(posedge vif.clk);
        end

        // Sau khi đã đẩy hết dữ liệu vào, phần cứng vẫn cần N chu kỳ clock nữa 
        // để "chảy" nốt các phép tính ra tới góc dưới cùng bên phải của mảng.
        // Ta đẩy thêm số 0 vào để ép kết quả cuối cùng trôi ra ngoài.
        repeat(N) begin
            vif.a_in_bus <= 0;
            vif.b_in_bus <= 0;
            @(posedge vif.clk);
        end
    endtask
endclass
