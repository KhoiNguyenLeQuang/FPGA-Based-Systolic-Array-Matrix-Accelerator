// Data sequence
class gemm_corner_seq extends uvm_sequence #(gemm_seq_item);
    // Đăng ký object này với UVM factory
    `uvm_object_utils(gemm_corner_seq) 

    function new(string name = "gemm_corner_seq");
        super.new(name);
    endfunction

    task body();
        gemm_seq_item item;

        // 1. All zeros
        item = gemm_seq_item::type_id::create("item");
        start_item(item);
        if(!item.randomize()) `uvm_error("SEQ", "Randomization failed")
        
        // Ghi đè dữ liệu ngẫu nhiên: Ép ma trận A toàn số 0, ma trận B toàn số cực đại (255)
        for(int i=0; i<4; i++) for(int j=0; j<4; j++) begin
            item.matrix_A[i][j] = 8'h00; // 0
            item.matrix_B[i][j] = 8'hFF; // 255
        end
        item.compute_expected(); // Tính toán giá trị expected
        finish_item(item);       // Gửi đi

        // 2. Max Value Stress
        // Ép cả 2 ma trận A và B đều bằng 255 (giá trị tối đa của 8-bit).
        // Mục đích: Kiểm tra xem các bộ cộng tích lũy (accumulator) 32-bit của phần cứng có bị tràn (overflow) hoặc lỗi tính toán khi chạy hết công suất hay không.
        item = gemm_seq_item::type_id::create("item");
        start_item(item);
        if(!item.randomize()) `uvm_error("SEQ", "Randomization failed")
        
        for(int i=0; i<4; i++) for(int j=0; j<4; j++) begin
            item.matrix_A[i][j] = 8'hFF; // 255
            item.matrix_B[i][j] = 8'hFF; // 255
        end
        item.compute_expected(); 
        finish_item(item);

        // 3. Identity Matrix
        // Ép ma trận A thành ma trận đơn vị (đường chéo bằng 1, còn lại bằng 0).
        // Ma trận B được gán các giá trị tăng dần (0, 1, 2, ..., 33).
        // Mục đích: Theo toán học, Ma trận Đơn vị (A) x B = chính ma trận B.
        // Kiểm tra xem phần cứng có giữ nguyên vẹn được ma trận B ở đầu ra hay không.
        item = gemm_seq_item::type_id::create("item");
        start_item(item);
        if(!item.randomize()) `uvm_error("SEQ", "Randomization failed")
        
        for(int i=0; i<4; i++) for(int j=0; j<4; j++) begin
            // Nếu nằm trên đường chéo (i == j) thì bằng 1, ngược lại bằng 0
            item.matrix_A[i][j] = (i == j) ? 8'h01 : 8'h00; 
            // Tạo dữ liệu tăng dần để dễ quan sát (ví dụ hàng 1 cột 2 sẽ là 12)
            item.matrix_B[i][j] = (i * 10) + j;      
        end
        item.compute_expected(); 
        finish_item(item);
    endtask
endclass


// Test class (ta có thể thấy rằng gemm_corner_test là expansion của gemm_base_test
class gemm_corner_test extends gemm_base_test; 
    // Đăng ký bài test này với UVM factory
    `uvm_component_utils(gemm_corner_test) 

    function new(string name = "gemm_corner_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // run_phase: Kích hoạt chuỗi kịch bản đặc biệt vừa định nghĩa ở trên
    virtual task run_phase(uvm_phase phase);
        gemm_corner_seq seq;
        
        // Giữ chân UVM không cho tắt mô phỏng
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Executing Corner Case Test Execution...", UVM_LOW)
        
        // Khởi tạo kịch bản test corner
        seq = gemm_corner_seq::type_id::create("seq");
        
        // Bắt đầu đẩy 3 ma trận đặc biệt này vào sequencer
        seq.start(env.agent.sequencer); 
        
        // Sau khi gửi xong ma trận cuối cùng, phải chờ thêm 30 chu kỳ clock 
        // để dữ liệu chạy hết qua các đường ống (pipeline) của mảng Systolic 
        // và Monitor có đủ thời gian bắt được kết quả đầu ra.
        repeat(30) @(posedge env.agent.driver.vif.clk);
        
        // Hoàn thành bài test, cho phép dừng mô phỏng
        phase.drop_objection(this);
    endtask
endclass
