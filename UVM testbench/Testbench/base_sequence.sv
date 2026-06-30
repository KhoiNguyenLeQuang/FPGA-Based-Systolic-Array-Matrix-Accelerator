// Lớp này định nghĩa một kịch bản (sequence) dùng để sinh ra các gói dữ liệu (gemm_seq_item)
class gemm_base_seq extends uvm_sequence #(gemm_seq_item);
    // Đăng ký object này với UVM factory
    `uvm_object_utils(gemm_base_seq)

    // Số lượng giao dịch (số cặp ma trận) mặc định sẽ được tạo và gửi đi. 
    int num_transactions = 10; 

    function new(string name = "gemm_base_seq");
        super.new(name);
    endfunction

    task body();
        gemm_seq_item item; // Khai báo một biến để chứa gói dữ liệu (transaction)
        
        // Vòng lặp để tạo ra đúng số lượng gói dữ liệu yêu cầu
        repeat(num_transactions) begin 
            // 1. Khởi tạo một gói dữ liệu mới (trống rỗng) bằng hệ thống UVM factory
            item = gemm_seq_item::type_id::create("item");
            
            // 2. Xin phép sequencer để bắt đầu gửi gói dữ liệu này xuống cho driver
            start_item(item);
            
            // 3. Đổ dữ liệu ngẫu nhiên vào các ma trận A và B bên trong gói dữ liệu.
            // Nếu việc tạo ngẫu nhiên bị lỗi (do ràng buộc sai), báo lỗi nghiêm trọng (fatal) và dừng chạy.
            if (!item.randomize()) `uvm_fatal("SEQ", "Randomization failed!")
            
            // 4. Ngay sau khi có giá trị ngẫu nhiên của A và B, tự động tính luôn kết quả chuẩn C = A * B.
            // Việc này giúp Scoreboard sau này có sẵn đáp án đúng để so sánh.
            item.compute_expected();
            
            // 5. Đẩy gói dữ liệu hoàn chỉnh xuống cho driver và chờ driver xử lý xong thì mới quay lại vòng lặp để tạo gói tiếp theo.
            finish_item(item);
        end
    endtask
endclass
