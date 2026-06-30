// Lớp này kế thừa từ uvm_sequence_item. Nó KHÔNG phải là một component (linh kiện cố định),
// mà là một Object (đối tượng dữ liệu động, được sinh ra và biến mất liên tục).
class gemm_seq_item extends uvm_sequence_item;
    
    // ĐỂ Ý KỸ: Ta dùng `uvm_object_utils chứ không phải `uvm_component_utils.
    // Vì đây là vật thể dữ liệu di động, không tham gia vào cấu trúc cây cố định của UVM.
    `uvm_object_utils(gemm_seq_item)

    // 1. DỮ LIỆU ĐẦU VÀO (DÙNG ĐỂ NGẪU NHIÊN HÓA - RANDOMIZATION)
    // Từ khóa 'rand' báo cho UVM biết: "Mỗi khi tui gọi lệnh .randomize(), 
    // hãy tự động đổ các số ngẫu nhiên vào 2 ma trận này giùm tui".
    
    rand bit [WIDTH-1:0]  matrix_A    [N][N]; // Ma trận vuông A (4x4), mỗi ô 8-bit
    rand bit [WIDTH-1:0]  matrix_B    [N][N]; // Ma trận vuông B (4x4), mỗi ô 8-bit

    // 2. KẾT QUẢ ĐẦU RA (KHÔNG CÓ 'rand' VÌ ĐÂY LÀ KẾT QUẢ TÍNH TOÁN)
    
    // Ma trận kết quả KỲ VỌNG (Expected - Đáp án chuẩn):
    // Do mô hình phần mềm của chúng ta tự tính trước. Mỗi ô rộng 32-bit.
    bit [ACC_WIDTH-1:0]   exp_matrix_C[N][N];
    
    // Ma trận kết quả THỰC TẾ (Actual - Bài làm của Chip):
    // Do Monitor "nhìn" từ chân Chip rồi chép ngược vào đây để Scoreboard chấm điểm.
    bit [ACC_WIDTH-1:0]   act_matrix_C[N][N];

    function new(string name = "gemm_seq_item");
        super.new(name);
    endfunction

    // 3. MÔ HÌNH TOÁN HỌC THAM CHIẾU
    // Hàm này dùng thuật toán nhân ma trận kinh điển (3 vòng lặp for lồng nhau) 
    // chạy bằng phần mềm thuần túy, đảm bảo độ chính xác tuyệt đối 100%.
    function void compute_expected();
        for (int i = 0; i < N; i++) begin          // Duyệt qua từng hàng của ma trận A
            for (int j = 0; j < N; j++) begin      // Duyệt qua từng cột của ma trận B
              exp_matrix_C[i][j] = 0;              // Khởi tạo ô kết quả bằng 0 trước khi cộng dồn
                for (int k = 0; k < N; k++) begin  // Vòng lặp tích lũy (Cộng dồn Tích của Hàng nhân Cột)
                    exp_matrix_C[i][j] += matrix_A[i][k] * matrix_B[k][j];
                end
            end
        end
    endfunction
endclass
