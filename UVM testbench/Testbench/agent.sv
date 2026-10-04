// gemm_agent: groups the sequencer, driver and monitor for the systolic array interface.
// The environment reaches into it as agent.sequencer, agent.driver and agent.monitor.
class gemm_agent extends uvm_agent;
    `uvm_component_utils(gemm_agent)

    uvm_sequencer #(gemm_seq_item) sequencer;
    gemm_driver                    driver;
    gemm_monitor                   monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer = uvm_sequencer#(gemm_seq_item)::type_id::create("sequencer", this);
        driver    = gemm_driver::type_id::create("driver", this);
        monitor   = gemm_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Driver pulls sequence items from the sequencer
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
