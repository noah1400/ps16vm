$IP = 0
$SP = 1
$FP = 2
$ACC = 3
$R0 = 4
$R1 = 5
$R2 = 6
$R3 = 7
$R4 = 8
$R5 = 9
$R6 = 10
$R7 = 11
$R8 = 12
$R9 = 13
$R10 = 14
$R11 = 15
$R12 = 16
$R13 = 17
$R14 = 18
$R15 = 19
$STACK_BASE = [uint16]::Parse("FFFF", [Globalization.NumberStyles]::HexNumber)

# OP codes
$OP_NOP = 0
$OP_MOV = 1 # MOV R0, R1
$OP_MOV_MEM = 101 # MOV R0, 0x0000000000000000 -> R0 = MEM[0x0000000000000000]
$OP_MOV_MEM_R = 102 # MOV 0x0000000000000000, R0 -> MEM[0x0000000000000000] = R0
$OP_MOV_IMM = 103 # MOV R0, 0x0000000000000000 -> R0 = 0x0000000000000000
$OP_ADD = 2 # ADD R0, R1 -> R0 = R0 + R1
$OP_SUB = 3 # SUB R0, R1 -> R0 = R0 - R1
$OP_MUL = 4 # MUL R0, R1 -> R0 = R0 * R1
$OP_DIV = 5 # DIV R0, R1 -> R0 = R0 / R1
$OP_MOD = 6 # MOD R0, R1 -> R0 = R0 % R1
$OP_AND = 7 # AND R0, R1 -> R0 = R0 & R1
$OP_OR = 8 # OR R0, R1 -> R0 = R0 | R1
$OP_XOR = 9 # XOR R0, R1 -> R0 = R0 ^ R1
$OP_SHL = 10 # SHL R0, R1 -> R0 = R0 << R1
$OP_SHR = 11 # SHR R0, R1 -> R0 = R0 >> R1
$OP_CMP = 12 # CMP R0, R1 -> ACC = R0 - R1
$OP_JMP = 13 # JMP 0x0000000000000000
$OP_JE = 14 # JE 0x0000000000000000
$OP_JNE = 15 # JNE 0x0000000000000000
$OP_JG = 16 # JG 0x0000000000000000
$OP_JL = 17 # JL 0x0000000000000000
$OP_CALL = 18 # CALL 0x0000000000000000
$OP_RET = 19 # RET
$OP_PUSH = 20 # PUSH R0
$OP_POP = 21 # POP R0
$OP_HLT = 22 # HLT

function New-Mem {
    param (
        [uint16]$size
    )
    $mem = New-Object PSObject
    $mem | Add-Member -MemberType NoteProperty -Name mem8 -Value (New-Object 'byte[]' $size)
    return $mem
}

function New-Device {
    param (
        [string]$name,
        [object]$mem
    )
    $dev = New-Object PSObject
    $dev | Add-Member -MemberType NoteProperty -Name name -Value $name
    $dev | Add-Member -MemberType NoteProperty -Name mem -Value $mem
    $dev | Add-Member -MemberType ScriptMethod -Name fetch16 -Value {
        param (
            [uint16]$address
        )
        $bytes = $this.mem.mem8[$address], $this.mem.mem8[$address + 1]
        if ([BitConverter]::IsLittleEndian) {
            return [BitConverter]::ToUInt16($bytes, 0)
        } else {
            return [BitConverter]::ToUInt16($bytes[1], $bytes[0])
        }
    }
    $dev | Add-Member -MemberType ScriptMethod -Name store16 -Value {
        param (
            [uint16]$address,
            [uint16]$value
        )
        $bytes = [BitConverter]::GetBytes($value)
        if ([BitConverter]::IsLittleEndian) {
            $bytes = $bytes[0], $bytes[1]
        } else {
            $bytes = $bytes[1], $bytes[0]
        }
        $this.mem.mem8[$address] = $bytes[0]
        $this.mem.mem8[$address + 1] = $bytes[1]
    }
    $dev | Add-Member -MemberType ScriptMethod -Name fetch8 -Value {
        param (
            [uint16]$address
        )
        return $this.mem.mem8[$address]
    }
    
    $dev | Add-Member -MemberType ScriptMethod -Name store8 -Value {
        param (
            [uint16]$address,
            [byte]$value
        )
        $this.mem.mem8[$address] = $value
    }

    return $dev
}

function New-MMR {
    param (
        [object]$device,
        [uint16]$startAddress,
        [uint16]$endAddress,
        [uint16]$remap
    )

    $mmr = New-Object PSObject
    $mmr | Add-Member -MemberType NoteProperty -Name device -Value $device
    $mmr | Add-Member -MemberType NoteProperty -Name startAddress -Value $startAddress
    $mmr | Add-Member -MemberType NoteProperty -Name endAddress -Value $endAddress
    $mmr | Add-Member -MemberType NoteProperty -Name remap -Value $remap

    return $mmr
}

function New-MM {
    $mm = New-Object PSObject
    $mm | Add-Member -MemberType NoteProperty -Name count -Value 0
    $mm | Add-Member -MemberType NoteProperty -Name regions -Value @()
    return $mm
}

function Add-MMR {
    param (
        [object]$mm,
        [object]$mmr
    )
    $mm.count++
    $mm.regions += $mmr
}

function Find-MMR {
    param (
        [object]$mm,
        [uint16]$address
    )
    foreach ($mmr in $mm.regions) {
        # Compare address with start address and output
        if ($address -ge $mmr.startAddress -and $address -le $mmr.endAddress) {
            return $mmr
        }
    }
    return $null
}
function Fetch16 {
    param (
        [object]$mm,
        [uint16]$address
    )
    $mmr = Find-MMR -mm $mm -address $address
    if ($null -eq $mmr) {
        return 0
    }
    if ($mmr.remap -eq 1) {
        return $mmr.device.fetch16.Invoke($address - $mmr.startAddress)
    }
    return $mmr.device.fetch16.Invoke($address)
}

function Store16 {
    param (
        [object]$mm,
        [uint16]$address,
        [uint16]$value
    )
    $mmr = Find-MMR -mm $mm -address $address
    if ($null -eq $mmr) {
        return
    }
    if ($mmr.remap -eq 1) {
        $mmr.device.store16.Invoke($address - $mmr.startAddress, $value)
        return
    }
    $mmr.device.store16.Invoke($address, $value)
}

function Fetch8 {
    param (
        [object]$mm,
        [uint16]$address
    )
    $mmr = Find-MMR -mm $mm -address $address

    if ($null -eq $mmr) {
        Write-Host 'Null'
        return 0
    }
    if ($mmr.remap -eq 1) {
        return $mmr.device.fetch8.Invoke($address - $mmr.startAddress)
    }
    return $mmr.device.fetch8.Invoke($address)
}

function Store8 {
    param (
        [object]$mm,
        [uint16]$address,
        [byte]$value
    )
    $mmr = Find-MMR -mm $mm -address $address
    if ($null -eq $mmr) {
        Write-Host 'No MMR found.'
        return
    }
    if ($mmr.remap -eq 1) {
        $mmr.device.store8.Invoke($address - $mmr.startAddress, $value)
        return
    }
    $mmr.device.store8.Invoke($address, $value)
}

# CPU functions

function New-CPU {
    $cpu = New-Object PSObject
    $cpu | Add-Member -MemberType NoteProperty -Name mm -Value (New-MM)
    $cpu | Add-Member -MemberType NoteProperty -Name registers -Value (New-Object 'uint16[]' 20)
    return $cpu
}

function Dereference-Reg {
    param (
        [object]$cpu,
        [uint16]$index
    )
    return Fetch16 -mm $cpu.mm -address $cpu.registers[$index]
}

function Store-At-Reg {
    param (
        [object]$cpu,
        [uint16]$index,
        [uint16]$value
    )
    $cpu.registers[$index] = $value
}

function Push-Stack {
    param (
        [object]$cpu,
        [uint16]$value
    )
    $cpu.registers[$SP] -= 2
    Write-Host ('Pushing 0x{0:X16} to 0x{1:X16}' -f $value, $cpu.registers[$SP])
    Store16 -mm $cpu.mm -address $cpu.registers[$SP] -value $value
}

function Pop-Stack {
    param (
        [object]$cpu
    )
    $value = Fetch16 -mm $cpu.mm -address $cpu.registers[$SP]
    $cpu.registers[$SP] += 2
    return $value
}

function Dump-Mem {
    # MEM 0x0000000000000000-0x00000000FFFFFFFF:
    # 00000000: 0xFF 0xFF 0xFF ....
    param (
        [object]$mem,
        [uint16]$start,
        [uint16]$end
    )
    $address = $start
    if ($end -gt $mem.mem8.Length) {
        $end = $mem.mem8.Length
    }
    while ($address -le $end) {
        $line = '{0:X8}: ' -f $address
        for ($i = 0; $i -lt 16; $i++) {
            $line += '{0:X2} ' -f $mem.mem8[$address++]
        }
        Write-Host $line
    }
}

function Dump-Reg {
    param (
        [object]$cpu
    )
    for ($i = 0; $i -lt 20; $i++) {
        Write-Host ('{0}: 0x{1:X4}' -f @('IP', 'SP', 'FP', 'ACC', 'R0', 'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15')[$i], $cpu.registers[$i])
    }
}

function Write-Mem {
    param (
        [object]$mem,
        [uint16]$start,
        [byte[]]$data
    )
    $address = $start
    foreach ($byte in $data) {
        $mem.mem8[$address++] = $byte
    }
}

function Fetch8-CPU {
    param (
        [object]$cpu
    )
    $value = Fetch8 -mm $cpu.mm -address $cpu.registers[$IP]
    $cpu.registers[$IP]++
    return $value
}

function Fetch16-CPU {
    param (
        [object]$cpu
    )
    $value = Fetch16 -mm $cpu.mm -address $cpu.registers[$IP]
    $cpu.registers[$IP] += 2
    return $value
}

function Run-Step {
    param (
        [object]$cpu
    )
    $op = Fetch8-CPU -cpu $cpu
    switch ($op) {
        $OP_NOP {
            # Do nothing
            $cpu.registers[$IP]++
        }
        $OP_MOV {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] = $cpu.registers[$r2_index]
        }
        $OP_MOV_MEM {
            # MOV R0, 0x0000000000000000 -> R0 = MEM[0x0000000000000000]
            $r_index = Fetch8-CPU -cpu $cpu
            $address = Fetch16-CPU -cpu $cpu
            $cpu.registers[$r_index] = Fetch16 -mm $cpu.mm -address $address
        }
        $OP_MOV_MEM_R {
            # MOV 0x0000000000000000, R0 -> MEM[0x0000000000000000] = R0
            $address = Fetch16-CPU -cpu $cpu
            $r_index = Fetch8-CPU -cpu $cpu
            Store16 -mm $cpu.mm -address $address -value $cpu.registers[$r_index]
        }
        $OP_MOV_IMM {
            # MOV R0, 0x0000000000000000 -> R0 = 0x0000000000000000
            $r_index = Fetch8-CPU -cpu $cpu
            $value = Fetch16-CPU -cpu $cpu
            $cpu.registers[$r_index] = $value
        }
        $OP_ADD {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] += $cpu.registers[$r2_index]
        }
        $OP_SUB {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] -= $cpu.registers[$r2_index]
        }
        $OP_MUL {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] *= $cpu.registers[$r2_index]
        }
        $OP_DIV {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] /= $cpu.registers[$r2_index]
        }
        $OP_MOD {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] %= $cpu.registers[$r2_index]
        }
        $OP_AND {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] = $cpu.registers[$r1_index] -band $cpu.registers[$r2_index]
        }
        $OP_OR {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] = $cpu.registers[$r1_index] -bor $cpu.registers[$r2_index]
        }
        $OP_XOR {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] = $cpu.registers[$r1_index] -bxor $cpu.registers[$r2_index]
        }
        $OP_SHL {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] = $cpu.registers[$r1_index] -shl $cpu.registers[$r2_index]
        }
        $OP_SHR {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r1_index] = $cpu.registers[$r1_index] -shr $cpu.registers[$r2_index]
        }
        $OP_CMP {
            $r1_index = Fetch8-CPU -cpu $cpu
            $r2_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$ACC] = $cpu.registers[$r1_index] - $cpu.registers[$r2_index]
        }
        $OP_JMP {
            $address = Fetch16-CPU -cpu $cpu
            $cpu.registers[$IP] = $address
        }
        $OP_JE {
            $address = Fetch16-CPU -cpu $cpu
            if ($cpu.registers[$ACC] -eq 0) {
                $cpu.registers[$IP] = $address
            }
        }
        $OP_JNE {
            $address = Fetch16-CPU -cpu $cpu
            if ($cpu.registers[$ACC] -ne 0) {
                $cpu.registers[$IP] = $address
            }
        }
        $OP_JG {
            $address = Fetch16-CPU -cpu $cpu
            if ($cpu.registers[$ACC] -gt 0) {
                $cpu.registers[$IP] = $address
            }
        }
        $OP_JL {
            $address = Fetch16-CPU -cpu $cpu
            if ($cpu.registers[$ACC] -lt 0) {
                $cpu.registers[$IP] = $address
            }
        }
        $OP_CALL {
            $address = Fetch16-CPU -cpu $cpu
            Push-Stack -cpu $cpu -value $cpu.registers[$IP]
            $cpu.registers[$IP] = $address
        }
        $OP_RET {
            $address = Pop-Stack -cpu $cpu
            $cpu.registers[$IP] = $address
        }
        $OP_PUSH {
            $r_index = Fetch8-CPU -cpu $cpu
            Push-Stack -cpu $cpu -value $cpu.registers[$r_index]
        }
        $OP_POP {
            $r_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r_index] = Pop-Stack -cpu $cpu
        }
        $OP_HLT {
            # Halt
        }
    }
    return $op
}

function Main {
    # Create memory
    $mem = New-Mem -size $([uint16]::Parse("FFFF", [Globalization.NumberStyles]::HexNumber))
    $memDev = New-Device -name 'mem' -mem $mem
    $s = [uint16]::Parse("0", [Globalization.NumberStyles]::HexNumber)
    $e = [uint16]::Parse("FFFF", [Globalization.NumberStyles]::HexNumber)
    $memMMR = New-MMR -device $memDev -startAddress $s -endAddress $e -remap 0
    $cpu = New-CPU
    Add-MMR -mm $cpu.mm -mmr $memMMR
    $cpu.registers[$IP] = 0
    $cpu.registers[$SP] = $STACK_BASE

    # Flash memory
    Write-Mem -mem $mem -start 0 -data @(
        $OP_MOV_IMM, $R0, 0x01, 0x00,
        $OP_MOV_IMM, $R1, 0x0F, 0x00,
        $OP_ADD, $R0, $R1,
        $OP_ADD, $R2, $R1,
        $OP_PUSH, $R0,
        $OP_PUSH, $R1,
        $OP_PUSH, $R2,
        $OP_POP, $R3,
        $OP_POP, $R4,
        $OP_POP, $R5,
        $OP_JMP, 0x00, 0x00,
        $OP_HLT
    )

    # Dump memory
    Dump-Mem -mem $mem -start 0 -end 0x0030
    Read-Host 'Press Enter to continue'

    # Run
    while (($op = Run-Step -cpu $cpu) -ne $OP_HLT) {
        Write-Host ('OP: {0:X2}' -f $op)
        Dump-Reg -cpu $cpu
        Dump-Mem -mem $mem -start ($cpu.registers[$SP]) -end $STACK_BASE
        Read-Host 'Press Enter to continue'
    }

    # Dump memory
    Dump-Mem -mem $mem -start 0 -end 0x0010
}

Main
