import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_cdc_logic(dut):
    """
    Tests functionality: Reset -> Idle -> Capture -> Stability -> Re-arm.
    """
    
    # 1. Setup Clock (100 MHz)
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # 2. Initialize
    dut.rst_n.value           = 0
    dut.trigger_async_n.value = 1  # Inactive (High)
    dut.data_in.value         = 0x00
    
    await Timer(50, unit="ns")
    dut.rst_n.value = 1
    await Timer(20, unit="ns")
    
    dut._log.info("--- STARTING TESTS ---")

    # -------------------------------------------------------
    # TEST 1: IDLE CHECK
    # Ensure output does not change if trigger is High
    # -------------------------------------------------------
    dut.data_in.value = 0xAA
    await Timer(50, unit="ns") # Wait several clocks
    
    assert dut.data_out.value == 0x00, \
        f"Idle Error: Output changed! Got {dut.data_out.value}"
    
    dut._log.info("-> IDLE CHECK PASSED")

    # -------------------------------------------------------
    # TEST 2: SNAPSHOT CAPTURE
    # Drop trigger (High -> Low) and check if data is latched
    # -------------------------------------------------------
    dut.trigger_async_n.value = 0
    
    # Wait for Synchronizer (approx 3 clock cycles)
    await Timer(40, unit="ns")
    
    assert dut.data_out.value == 0xAA, \
        f"Capture Error: Expected 0xAA, Got {dut.data_out.value}"
        
    dut._log.info("-> CAPTURE CHECK PASSED")

    # -------------------------------------------------------
    # TEST 3: STABILITY (FREEZE)
    # Change input while trigger is held Low. Output must NOT change.
    # -------------------------------------------------------
    dut.data_in.value = 0xFF
    await Timer(50, unit="ns")
    
    assert dut.data_out.value == 0xAA, \
        f"Stability Error: Output changed to 0xFF! Should be frozen at 0xAA."
        
    dut._log.info("-> STABILITY CHECK PASSED")

    # -------------------------------------------------------
    # TEST 4: RE-ARM AND NEW CAPTURE
    # Raise trigger, change data, drop trigger again.
    # -------------------------------------------------------
    dut.trigger_async_n.value = 1
    await Timer(50, unit="ns") # Allow sync logic to reset
    
    dut.data_in.value = 0x55
    await Timer(10, unit="ns")
    
    # Trigger Event
    dut.trigger_async_n.value = 0
    await Timer(40, unit="ns") # Wait for sync
    
    assert dut.data_out.value == 0x55, \
        f"Re-arm Error: Expected 0x55, Got {dut.data_out.value}"
        
    dut._log.info("-> RE-ARM CHECK PASSED")

    dut._log.info("====================")
    dut._log.info("  ALL TESTS PASSED  ")
    dut._log.info("====================")