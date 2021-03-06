class core_monitor extends uvm_monitor;
    `uvm_component_utils(core_monitor)

    uvm_analysis_port #(memory_transaction) monitor_analysis_port;
    uvm_put_port #(memory_transaction) monitor_port;

    virtual interface core_if vif;
    virtual interface reg_if reg_vif;
    
    memory_transaction memory_transaction_h;
    t_transaction transaction;
    core_agent_config core_agent_config_h;

    int file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db #(core_agent_config)::get(this, "", "core_config", core_agent_config_h))
            `uvm_fatal("CORE_MONITOR", "Failed to get configuration object");
        
        monitor_analysis_port = new("monitor_analysis_port", this);
        monitor_port          = new("monitor_port", this);

        vif     = core_agent_config_h.vif;
        reg_vif = core_agent_config_h.reg_vif;
    endfunction : build_phase 
    
        string s1 = "pc, r0, r1, r1, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15,16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,";
        string s2 = "mstatus, mip, mie, mtvec, mepc, mcause, mtval, mscratch, medeleg, midleg, mtimecmp, mtime,";
        string s3 = "sstatus, sip, sie, stvec, sepc, scause, stval, sscratch, sedeleg, sidleg, stimecmp,";
        string s4 = "ustatus, uip, uie, utvec, uepc, ucause, utval, uscratch, utimecmp";
        
    task run_phase(uvm_phase phase);
        fork 
            begin
                monitor_operations();
            end

            begin
                log_regfile();
            end
        join
    endtask : run_phase

    function void wrap_transaction();
        case(vif.transducer_l15_rqtype)
            `STORE_RQ: transaction.op_type = WRITE;
            `LOAD_RQ: transaction.op_type = READ;
            default: transaction.op_type = NOOP;
        endcase

        if(transaction.op_type != NOOP) begin
            case(vif.transducer_l15_size)
                `MSG_DATA_SIZE_1B: transaction.op_size = BYTE;
                `MSG_DATA_SIZE_2B: transaction.op_size = HALF;
                `MSG_DATA_SIZE_4B: transaction.op_size = FULL;
            endcase

            transaction.address = vif.transducer_l15_address;
            transaction.data = vif.transducer_l15_data;
        end

        memory_transaction_h.set_transaction(transaction);
    endfunction : wrap_transaction

    task log_regfile();
        file = $fopen("reg_dump.csv", "w");
        $fdisplay(file, {s1, s2, s3, s4});

        forever begin
            @(reg_vif.pc);
            if (reg_vif.pc != 0)
            $fdisplay(file, reg_vif.convert2string());
        end
    endtask : log_regfile

    task monitor_operations();
        memory_transaction_h = memory_transaction::type_id::create("memory_transaction_h", this);
        forever begin
            @(posedge vif.clk); #1;
            wrap_transaction();
            if(vif.transducer_l15_val == 1) begin
                if((memory_transaction_h.get_op_type() == WRITE) 
                    || (memory_transaction_h.get_op_type() == READ)) begin
                    monitor_analysis_port.write(memory_transaction_h);
                    monitor_port.put(memory_transaction_h);
                end 
            end
        end
    endtask : monitor_operations

endclass : core_monitor
