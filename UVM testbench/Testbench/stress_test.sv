// 1. KỊCH BẢN TỔNG LỰC (GEMM STRESS SEQUENCE)
class gemm_stress_seq extends uvm_sequence #(gemm_seq_item);
    `uvm_object_utils(gemm_stress_seq)
 
    // Mặc định chạy 1000 giao dịch ngẫu nhiên
    int unsigned num_transactions = 1000;
 
    function new(string name = "gemm_stress_seq");
        super.new(name);
    endfunction
 
    task body();
        gemm_seq_item item;
 
        // Tạo mảng chứa 5 giá trị đặc biệt tương ứng với 5 giỏ (bins) trong file Coverage
        bit [7:0] vals[5];
        vals[0] = 8'd0;    // Đại diện cho giỏ 'zero'
        vals[1] = 8'd32;   // Đại diện cho giỏ 'low' [1:63]
        vals[2] = 8'd100;  // Đại diện cho giỏ 'mid' [64:191]
        vals[3] = 8'd200;  // Đại diện cho giỏ 'hi'  [192:254]
        vals[4] = 8'd255;  // Đại diện cho giỏ 'max_val'
 
        // PHASE 1: BẮN TẢI ĐỂ ĐẠT 100% CROSS-COVERAGE
        `uvm_info("STRESS_SEQ", "Phase 1: Driving 25 targeted cross-coverage transactions...", UVM_LOW)
 
        // 2 vòng lặp lồng nhau quét qua 5 giá trị của A và 5 giá trị của B 
        // Tạo ra đúng 5 x 5 = 25 tổ hợp ma trận đặc biệt.
        for (int ai = 0; ai < 5; ai++) begin
            for (int bi = 0; bi < 5; bi++) begin
                item = gemm_seq_item::type_id::create("item");
                
                // Xin quyền gửi hàng từ Sequencer
                start_item(item);
 
                // Randomize trước để lấp đầy các biến khác (nếu có)
                if (!item.randomize())
                    `uvm_fatal("SEQ", "stress_seq: randomization failed")
 
                // Đè giá trị (Override)
                // Ép toàn bộ 16 ô của ma trận A nhận giá trị vals[ai]
                // Ép toàn bộ 16 ô của ma trận B nhận giá trị vals[bi]
                foreach (item.matrix_A[i,j]) item.matrix_A[i][j] = vals[ai];
                foreach (item.matrix_B[i,j]) item.matrix_B[i][j] = vals[bi];
 
                // Tính toán đáp án đúng SAU KHI đã ép giá trị cố định
                item.compute_expected();
                
                // 25 gói này chạy qua Driver sẽ kích hoạt bộ đếm Coverage 
                // tích đủ 25 dấu tick cho phần cross-coverage
                finish_item(item);
            end
        end
 
        `uvm_info("STRESS_SEQ", "Phase 1 complete — all 25 cross-bins targeted.", UVM_LOW)
 
        // PHASE 2: BACK-TO-BACK STRESS TEST
        `uvm_info("STRESS_SEQ", $sformatf("Phase 2: Driving %0d random back-to-back transactions...", num_transactions), UVM_LOW)
 
        // Lặp lại 1000 lần liên tục không nghỉ chu kỳ nào
        repeat (num_transactions) begin
            item = gemm_seq_item::type_id::create("item");
            start_item(item);
            
            if (!item.randomize())
                `uvm_fatal("SEQ", "stress_seq: randomization failed")
                
            item.compute_expected();
            finish_item(item);
        end
 
        `uvm_info("STRESS_SEQ", $sformatf("Stress sequence complete (%0d total transactions).", 25 + num_transactions), UVM_LOW)
    endtask
endclass : gemm_stress_seq
 
 
// 2. BÀI TEST TỔNG LỰC (GEMM STRESS TEST)
class gemm_stress_test extends gemm_base_test;
    `uvm_component_utils(gemm_stress_test)
 
    function new(string name = "gemm_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
 
    virtual task run_phase(uvm_phase phase);
        gemm_stress_seq seq;
        
        // Treo Objection để không cho mô phỏng tự ngắt
        phase.raise_objection(this);
 
        `uvm_info("TEST", "=== STARTING GEMM STRESS TEST (25 targeted + 1000 random) ===", UVM_NONE)
 
        // Khởi tạo kịch bản stress
        seq = gemm_stress_seq::type_id::create("seq");
        seq.num_transactions = 1000; // Cấu hình số lượng nhồi bom là 1000 ma trận
        
        // Kích hoạt kịch bản
        seq.start(env.agent.sequencer);
 
        // GIAI ĐOẠN VÉT ĐUÔI (DRAIN TIME):
        // Sau khi gửi xong ma trận thứ 1025, ta phải cố tình đợi thêm 30 nhịp clock.
        // Tại sao? Để Driver nháy reset nốt lần cuối, Monitor kịp thu hoạch ma trận cuối cùng, 
        // và Scoreboard kịp in chữ SUCCESS trước khi kịch bản tắt phụt máy
        repeat(30) @(posedge env.agent.driver.vif.clk);
 
        // Kiểm tra thành quả: Lấy điểm số từ bộ đếm Coverage in ra màn hình.
        `uvm_info("TEST", $sformatf("Coverage at end of stress test: %0.2f%%", env.coverage.gemm_cg.get_coverage()), UVM_NONE)
 
        `uvm_info("TEST", "=== GEMM STRESS TEST COMPLETE ===", UVM_NONE)
        
        // Thả Objection, đóng bài test sạch sẽ
        phase.drop_objection(this);
    endtask
endclass
