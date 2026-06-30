// Lớp này định nghĩa một bài test cơ bản (base test). Các bài test khác (rand, stress...) 
// thường sẽ kế thừa lại từ class này để đỡ phải viết lại code.
class gemm_base_test extends uvm_test;
    // Đăng ký bài test này với hệ thống UVM factory
    `uvm_component_utils(gemm_base_test)

    // Khai báo Environment. 
    gemm_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // BUILD PHASE: Giai đoạn chuẩn bị (xảy ra trước khi thời gian mô phỏng bắt đầu chạy)
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Chính thức tạo ra đối tượng môi trường (env) trong bộ nhớ
        env = gemm_env::type_id::create("env", this);
    endfunction

    // RUN PHASE: Giai đoạn chạy thực tế (có tiêu tốn thời gian mô phỏng)
    task run_phase(uvm_phase phase);
        // Khai báo một kịch bản (sequence) cơ bản để tạo dữ liệu
        gemm_base_seq seq;
        
        // Ngăn không cho UVM dừng chạy
        phase.raise_objection(this);
        
        // 1. Tạo kịch bản dữ liệu
        seq = gemm_base_seq::type_id::create("seq");
        
        // 2. Chuyển kịch bản này cho Sequencer để nó bắt đầu phân phát dữ liệu xuống cho Driver. Quá trình mô phỏng chính thức chạy ở đây.
        seq.start(env.agent.sequencer);
        
        // Khi kịch bản (sequence) chạy xong hết, UVM dừng mô phỏng.
        phase.drop_objection(this);
    endtask
endclass
