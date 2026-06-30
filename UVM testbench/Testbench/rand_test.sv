// Lớp này kế thừa từ gemm_base_test. Nó tái sử dụng toàn bộ Environment 
// đã được thiết lập sẵn, chỉ thay đổi số lượng dữ liệu được gửi đi.
class gemm_rand_test extends gemm_base_test;
    // Đăng ký bài test với hệ thống UVM factory
    `uvm_component_utils(gemm_rand_test)
 
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
 
    // RUN PHASE: Kịch bản chạy chính của bài test
    task run_phase(uvm_phase phase);
        // Sử dụng lại đúng kịch bản gốc (gemm_base_seq)
        gemm_base_seq seq;
        
        // Báo UVM giữ cho mô phỏng tiếp tục chạy
        phase.raise_objection(this);
        
        `uvm_info("TEST", "gemm_rand_test: 500 random transactions", UVM_LOW)
        
        // 1. Khởi tạo kịch bản
        seq = gemm_base_seq::type_id::create("seq");

		// Tăng số transactions lên 500 (ở base_test là 10)
        seq.num_transactions = 500;
        
        // 3. Bắt đầu đẩy 500 cặp ma trận này xuống phần cứng
        seq.start(env.agent.sequencer);
        
        `uvm_info("TEST", "gemm_rand_test complete.", UVM_LOW)
        
        // Chạy xong 500 cái, cho phép tắt mô phỏng
        phase.drop_objection(this);
    endtask
endclass
