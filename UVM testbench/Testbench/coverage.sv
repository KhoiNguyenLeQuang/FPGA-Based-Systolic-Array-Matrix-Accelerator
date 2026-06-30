// Lớp này kế thừa từ uvm_subscriber.
// Nó sẽ tự động "lắng nghe" mọi gói dữ liệu (gemm_seq_item) mà Monitor phát ra.
class gemm_coverage extends uvm_subscriber #(gemm_seq_item);
    // Đăng ký với UVM factory
    `uvm_component_utils(gemm_coverage)

    // Khai báo những gì cần theo dõi, ở đây ta theo dõi 2 biến a và b (8-bit)
    covergroup gemm_cg with function sample(bit [7:0] a, bit [7:0] b);
        
        // coverpoint cho biến a: Chia dải giá trị (0-255) thành các bins
        cp_a: coverpoint a {
            bins zero    = {0};         // Giỏ 1: Chỉ chứa giá trị 0
            bins low     = {[1:63]};    // Giỏ 2: Khoảng giá trị thấp
            bins mid     = {[64:191]};  // Giỏ 3: Khoảng giá trị trung bình
            bins hi      = {[192:254]}; // Giỏ 4: Khoảng giá trị cao
            bins max_val = {255};       // Giỏ 5: Chỉ chứa giá trị lớn nhất
        }
        
        // coverpoint cho biến b: Tương tự như a
        cp_b: coverpoint b {
            bins zero    = {0};
            bins low     = {[1:63]};
            bins mid     = {[64:191]};
            bins hi      = {[192:254]};
            bins max_val = {255};
        }
        
        // cross coverage
        // Nó kiểm tra TỔ HỢP CHÉO. Ví dụ: Nó sẽ kiểm tra xem bạn đã test trường hợp 
        // a = 0 đi kèm với b = 255 chưa? (5 giỏ a) x (5 giỏ b) = 25 tổ hợp cần phải test.
        cp_cross: cross cp_a, cp_b;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        // Khởi tạo gemm_cg để bắt đầu ghi chép
        gemm_cg = new();
    endfunction

    // UVM sẽ tự động kích hoạt hàm này mỗi khi Monitor dùng lệnh "ap.write(item)" để gửi dữ liệu về.
    function void write(gemm_seq_item t);
        // Duyệt qua từng phần tử trong ma trận 4x4
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                // Ghi nhận (sample) các giá trị thực tế của A và B vào sổ chấm công
                // Nếu giá trị này rơi vào tổ hợp chưa có, điểm coverage sẽ tăng lên.
                gemm_cg.sample(t.matrix_A[i][j], t.matrix_B[i][j]);
            end
        end
    endfunction
    
    // Report kết quả của test
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        // Lấy điểm tổng kết (từ 0 đến 100%) và in ra màn hình
        `uvm_info("COVERAGE", $sformatf("Total Functional Coverage: %0.2f%%", gemm_cg.get_coverage()), UVM_NONE)
    endfunction
endclass
