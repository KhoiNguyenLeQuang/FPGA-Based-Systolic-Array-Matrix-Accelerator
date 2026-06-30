class gemm_reset_seq extends uvm_sequence #(gemm_seq_item);
    // 1. Change the utils macro to object_utils
    `uvm_object_utils(gemm_reset_seq)

    // 2. Remove the 'parent' argument from the constructor
    function new(string name = "gemm_reset_seq");
        super.new(name);
    endfunction

    // 3. Change run_phase to the body() task
    task body();
        gemm_base_seq base_seq;
        
        `uvm_info("SEQ", "gemm_reset_seq: verifying clean accumulator after mid-compute rst", UVM_LOW)
        
        base_seq = gemm_base_seq::type_id::create("base_seq");
        base_seq.num_transactions = 20;
        
        // 4. Start the base sequence on the default sequencer
        base_seq.start(m_sequencer);

        `uvm_info("SEQ", "gemm_reset_seq complete.", UVM_LOW)
    endtask
endclass

class gemm_reset_test extends gemm_base_test;
    `uvm_component_utils(gemm_reset_test)
 
    function new(string name = "gemm_reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
 
    task run_phase(uvm_phase phase);
        gemm_base_seq stim_seq;
        phase.raise_objection(this);
        
        `uvm_info("TEST", "=== STARTING GEMM RESET TEST ===", UVM_LOW)
        
        // 1. Create a sequence with enough transactions to catch mid-compute
        stim_seq = gemm_base_seq::type_id::create("stim_seq");
        stim_seq.num_transactions = 40;
 
        // 2. Fork the sequence and the reset trigger together
        fork
            begin
                stim_seq.start(env.agent.sequencer);
            end
            begin
                // Let a few matrix operations process first
                repeat(15) @(posedge env.agent.driver.vif.clk);
                
                `uvm_info("TEST", "!!! ASSERTING HARDWARE RESET MID-COMPUTE !!!", UVM_LOW)
                env.agent.driver.vif.rst <= 1'b1;
                
                // Hold reset active for 5 clock cycles
                repeat(5) @(posedge env.agent.driver.vif.clk);
                
                `uvm_info("TEST", "DE-ASSERTING HARDWARE RESET", UVM_LOW)
                env.agent.driver.vif.rst <= 1'b0;
            end
        join_any
        
        // Kill any hung sequence threads caused by the abrupt reset
        disable fork;
        
        // 3. Recovery Phase: Run a clean sequence to verify accumulator cleared
        `uvm_info("TEST", "Running post-reset recovery transactions...", UVM_LOW)
        stim_seq = gemm_base_seq::type_id::create("recovery_seq");
        stim_seq.num_transactions = 10;
        stim_seq.start(env.agent.sequencer);
 
        `uvm_info("TEST", "=== GEMM RESET TEST COMPLETE ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass