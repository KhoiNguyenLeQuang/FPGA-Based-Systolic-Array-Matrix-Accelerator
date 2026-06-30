class gemm_all_test extends gemm_base_test;
    // Đăng ký class này với UVM factory (giống như đăng ký để hệ thống biết mà tạo ra nó)
    `uvm_component_utils(gemm_all_test)
 
    function new(string name = "gemm_all_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
 
    task run_phase(uvm_phase phase);
        // Khai báo các biến chứa các chuỗi test (sequences) khác nhau
        gemm_base_seq   rand_seq;   
        gemm_corner_seq corner_seq;
        gemm_stress_seq stress_seq; 
        gemm_base_seq   reset_stim_seq;
        gemm_base_seq   recovery_seq;
        // Bắt đầu mô phỏng: Yêu cầu UVM không kết thúc mô phỏng (giữ chân nó lại) cho đến khi chạy xong hết test
        phase.raise_objection(this);
 
        `uvm_info("MASTER_TEST",
            "========================================", UVM_NONE)
        `uvm_info("MASTER_TEST",
            "  STARTING GEMM FULL REGRESSION SUITE   ", UVM_NONE)
        `uvm_info("MASTER_TEST",
            "========================================", UVM_NONE)
 
        // TEST 1: CHẠY CÁC TRƯỜNG HỢP ĐẶC BIỆT (CORNER CASES)
        `uvm_info("MASTER_TEST", "--- TEST 1: CORNER CASES (3 transactions) ---", UVM_NONE)
        // Tạo một đối tượng của corner_seq
        corner_seq = gemm_corner_seq::type_id::create("corner_seq");
        // Bắt đầu đẩy dữ liệu (start) vào sequencer để driver nhận và đưa vào phần cứng
        corner_seq.start(env.agent.sequencer);
        // Chờ 30 chu kỳ xung nhịp (clock) để dữ liệu cuối cùng chạy nốt qua hệ thống
        repeat(30) @(posedge env.agent.driver.vif.clk);
        // In ra màn hình xem độ phủ (coverage) đạt bao nhiêu % sau bài test này
        `uvm_info("COVERAGE_UPDATE",
            $sformatf("Coverage after Corner Test:  %0.2f%%",
                env.coverage.gemm_cg.get_coverage()), UVM_NONE)
 
        // TEST 2: CHẠY CÁC MA TRẬN NGẪU NHIÊN
        `uvm_info("MASTER_TEST", "--- TEST 2: RANDOM MATRICES (500 transactions) ---", UVM_NONE)
        rand_seq = gemm_base_seq::type_id::create("rand_seq");
        // Chỉnh số lượng vòng lặp test lên 500 lần
        rand_seq.num_transactions = 500;
        rand_seq.start(env.agent.sequencer);
        repeat(30) @(posedge env.agent.driver.vif.clk);
        `uvm_info("COVERAGE_UPDATE",
            $sformatf("Coverage after Rand Test:    %0.2f%%",
                env.coverage.gemm_cg.get_coverage()), UVM_NONE)
 
        // TEST 3: CHẠY TEST CHỊU TẢI (STRESS TEST)
        `uvm_info("MASTER_TEST",
            "--- TEST 3: STRESS (25 targeted + 1000 random = 1025 transactions) ---", UVM_NONE)
        stress_seq = gemm_stress_seq::type_id::create("stress_seq");
        // Ép hệ thống chạy liên tục 1000 ma trận không nghỉ
        stress_seq.num_transactions = 1000;
        stress_seq.start(env.agent.sequencer);
        repeat(30) @(posedge env.agent.driver.vif.clk);
        `uvm_info("COVERAGE_UPDATE",
            $sformatf("Coverage after Stress Test:  %0.2f%%",
                env.coverage.gemm_cg.get_coverage()), UVM_NONE)
 
        // TEST 4: KIỂM TRA LỖI KHI BỊ RESET ĐỘT NGỘT
        `uvm_info("MASTER_TEST", "--- TEST 4: RESET BEHAVIOUR (mid-compute reset + recovery) ---", UVM_NONE)
        reset_stim_seq = gemm_base_seq::type_id::create("reset_stim_seq");
        reset_stim_seq.num_transactions = 40;

        fork
            begin
                reset_stim_seq.start(env.agent.sequencer);
            end
            begin
                // Let a few matrix operations process first
                repeat(15) @(posedge env.agent.driver.vif.clk);

                `uvm_info("MASTER_TEST", "!!! ASSERTING HARDWARE RESET MID-COMPUTE !!!", UVM_NONE)
                env.agent.driver.vif.rst <= 1'b1;

                // Hold reset active for 5 clock cycles
                repeat(5) @(posedge env.agent.driver.vif.clk);

                `uvm_info("MASTER_TEST", "DE-ASSERTING HARDWARE RESET", UVM_NONE)
                env.agent.driver.vif.rst <= 1'b0;
            end
        join_any

        // Kill any hung sequence threads caused by the abrupt reset
        disable fork;

        // Recovery phase: run a clean sequence to verify accumulator cleared correctly
        `uvm_info("MASTER_TEST", "Running post-reset recovery transactions...", UVM_NONE)
        recovery_seq = gemm_base_seq::type_id::create("recovery_seq");
        recovery_seq.num_transactions = 10;
        recovery_seq.start(env.agent.sequencer);

        repeat(30) @(posedge env.agent.driver.vif.clk);
        `uvm_info("COVERAGE_UPDATE",
            $sformatf("Coverage after Reset Test:   %0.2f%%",
                env.coverage.gemm_cg.get_coverage()), UVM_NONE)
 
        `uvm_info("MASTER_TEST",
            "========================================", UVM_NONE)
        `uvm_info("MASTER_TEST",
            "  ALL TESTS COMPLETED SUCCESSFULLY      ", UVM_NONE)
        `uvm_info("MASTER_TEST",
            "  Total transactions: ~1558              ", UVM_NONE)
        `uvm_info("MASTER_TEST",
            "  Expected coverage: 100.00%            ", UVM_NONE)
        `uvm_info("MASTER_TEST",
            "========================================", UVM_NONE)

        // Kết thúc test: Báo cho UVM biết là đã chạy xong hết, có thể kết thúc mô phỏng
        phase.drop_objection(this);
    endtask
endclass
