$ErrorActionPreference = "Stop"

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
$OP_CMP_IMM = 120 # CMP R0, 0x0000000000000000 -> ACC = R0 - 0x0000000000000000
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
$OP_INC = 23 # INC R0
$OP_DEC = 24 # DEC R0

function Map-Op-Code-To-String {
    param (
        [uint16]$op
    )
    switch ($op) {
        $OP_NOP { return 'NOP' }
        $OP_MOV { return 'MOV' }
        $OP_MOV_MEM { return 'MOV_MEM' }
        $OP_MOV_MEM_R { return 'MOV_MEM_R' }
        $OP_MOV_IMM { return 'MOV_IMM' }
        $OP_ADD { return 'ADD' }
        $OP_SUB { return 'SUB' }
        $OP_MUL { return 'MUL' }
        $OP_DIV { return 'DIV' }
        $OP_MOD { return 'MOD' }
        $OP_AND { return 'AND' }
        $OP_OR { return 'OR' }
        $OP_XOR { return 'XOR' }
        $OP_SHL { return 'SHL' }
        $OP_SHR { return 'SHR' }
        $OP_CMP { return 'CMP' }
        $OP_CMP_IMM { return 'CMP_IMM' }
        $OP_JMP { return 'JMP' }
        $OP_JE { return 'JE' }
        $OP_JNE { return 'JNE' }
        $OP_JG { return 'JG' }
        $OP_JL { return 'JL' }
        $OP_CALL { return 'CALL' }
        $OP_RET { return 'RET' }
        $OP_PUSH { return 'PUSH' }
        $OP_POP { return 'POP' }
        $OP_HLT { return 'HLT' }
        $OP_INC { return 'INC' }
        $OP_DEC { return 'DEC' }
        default { return 'UNKNOWN' }
    }
}

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
        }
        else {
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
        }
        else {
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
    $cpu | Add-Member -MemberType NoteProperty -Name stackframeSize -Value 0
    return $cpu
}

function Push-Stack {
    param (
        [object]$cpu,
        [uint16]$value
    )
    $cpu.registers[$SP] -= 2
    Store16 -mm $cpu.mm -address $cpu.registers[$SP] -value $value
    $cpu.stackframeSize += 2
}

function Pop-Stack {
    param (
        [object]$cpu
    )
    $value = Fetch16 -mm $cpu.mm -address $cpu.registers[$SP]
    $cpu.registers[$SP] += 2
    $cpu.stackframeSize -= 2
    return $value
}


function Push-State {
    param (
        [object]$cpu
    )
    # push all registers beginning from R0 to R15
    Push-Stack -cpu $cpu -value $cpu.registers[$R0]
    Push-Stack -cpu $cpu -value $cpu.registers[$R1]
    Push-Stack -cpu $cpu -value $cpu.registers[$R2]
    Push-Stack -cpu $cpu -value $cpu.registers[$R3]
    Push-Stack -cpu $cpu -value $cpu.registers[$R4]
    Push-Stack -cpu $cpu -value $cpu.registers[$R5]
    Push-Stack -cpu $cpu -value $cpu.registers[$R6]
    Push-Stack -cpu $cpu -value $cpu.registers[$R7]
    Push-Stack -cpu $cpu -value $cpu.registers[$R8]
    Push-Stack -cpu $cpu -value $cpu.registers[$R9]
    Push-Stack -cpu $cpu -value $cpu.registers[$R10]
    Push-Stack -cpu $cpu -value $cpu.registers[$R11]
    Push-Stack -cpu $cpu -value $cpu.registers[$R12]
    Push-Stack -cpu $cpu -value $cpu.registers[$R13]
    Push-Stack -cpu $cpu -value $cpu.registers[$R14]
    Push-Stack -cpu $cpu -value $cpu.registers[$R15]
    Push-Stack -cpu $cpu -value $cpu.registers[$IP]
    # push stackframe size + 2 (2 bytes)
    Push-Stack -cpu $cpu -value ($cpu.stackframeSize)
    # set frame pointer to stack pointer
    $cpu.registers[$FP] = $cpu.registers[$SP]
    # set stackframe size to 0
    $cpu.stackframeSize = 0
}

function Pop-State {
    param (
        [object]$cpu
    )
    $fpa = $cpu.registers[$FP]
    $cpu.registers[$SP] = $fpa
    $cpu.stackframeSize = Pop-Stack -cpu $cpu
    $sfs = $cpu.stackframeSize
    # pop IP
    $cpu.registers[$IP] = Pop-Stack -cpu $cpu
    # pop all registers beginning from R15 to R0
    $cpu.registers[$R15] = Pop-Stack -cpu $cpu
    $cpu.registers[$R14] = Pop-Stack -cpu $cpu
    $cpu.registers[$R13] = Pop-Stack -cpu $cpu
    $cpu.registers[$R12] = Pop-Stack -cpu $cpu
    $cpu.registers[$R11] = Pop-Stack -cpu $cpu
    $cpu.registers[$R10] = Pop-Stack -cpu $cpu
    $cpu.registers[$R9] = Pop-Stack -cpu $cpu
    $cpu.registers[$R8] = Pop-Stack -cpu $cpu
    $cpu.registers[$R7] = Pop-Stack -cpu $cpu
    $cpu.registers[$R6] = Pop-Stack -cpu $cpu
    $cpu.registers[$R5] = Pop-Stack -cpu $cpu
    $cpu.registers[$R4] = Pop-Stack -cpu $cpu
    $cpu.registers[$R3] = Pop-Stack -cpu $cpu
    $cpu.registers[$R2] = Pop-Stack -cpu $cpu
    $cpu.registers[$R1] = Pop-Stack -cpu $cpu
    $cpu.registers[$R0] = Pop-Stack -cpu $cpu

    $cpu.registers[$FP] = $fpa + $sfs
}

function Dump-Mem {
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
        Write-Host ('{0}: 0x{1:X4} ({1})' -f @('IP', 'SP', 'FP', 'ACC', 'R0', 'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15')[$i], $cpu.registers[$i])
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
            # convert to signed integer
            $v1 = [int16]$cpu.registers[$r1_index]
            $v2 = [int16]$cpu.registers[$r2_index]
            $result = $v1 - $v2
            $result = $result -band 0xFFFF
            $result = [convert]::ToUInt16($result)
            $cpu.registers[$ACC] = $result
        }
        $OP_CMP_IMM {
            $r_index = Fetch8-CPU -cpu $cpu
            $value = [int16](Fetch16-CPU -cpu $cpu)
            $result = $cpu.registers[$r_index] - $value
            $result = $result -band 0xFFFF
            $cpu.registers[$ACC] = $result
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

            $v1_temp = [int32]$cpu.registers[$ACC]

            if ($v1_temp -gt 32767) {
                $v1_temp = $v1_temp - 65536
            }
            $v1 = [int16]$v1_temp

            if ($v1 -gt 0) {
                $cpu.registers[$IP] = $address
            }
        }
        $OP_JL {
            $address = Fetch16-CPU -cpu $cpu
            # convert to signed integer
            $v1 = [int32]$cpu.registers[$ACC]

            if ($v1 -gt 32767) {
                $v1 = $v1 - 65536
            }
            $v1 = [int16]$v1
            if ($v1 -lt 0) {
                $cpu.registers[$IP] = $address
            }
        }
        $OP_CALL {
            $address = Fetch16-CPU -cpu $cpu
            Push-State -cpu $cpu 
            $cpu.registers[$IP] = $address
        }
        $OP_RET {
            Pop-State -cpu $cpu
        }
        $OP_PUSH {
            $r_index = Fetch8-CPU -cpu $cpu
            Push-Stack -cpu $cpu -value $cpu.registers[$r_index]
        }
        $OP_POP {
            $r_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r_index] = Pop-Stack -cpu $cpu
        }
        $OP_INC {
            $r_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r_index]++
        }
        $OP_DEC {
            $r_index = Fetch8-CPU -cpu $cpu
            $cpu.registers[$r_index]--
        }
        $OP_HLT {
            return $OP_HLT
        }
        default {
            Write-Host ('Unknown OP code: {0:X2}' -f $op)
            return $OP_HLT
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

    # Main routine
    Write-Mem -m $mem -start 0 -data @(
        # Assuming R0 is 0 at start
        $OP_INC, $R0, # R0++
        $OP_CMP_IMM, $R0, 0xFF, 0x00, # CMP R0, 0x00FF
        $OP_JE, 0x30, 0x00, # JE 0x0030 (HLT)
        $OP_CALL, 0x00, 0x01, # CALL 0x0100 (is_prime)
        $OP_CMP_IMM, $ACC, 0x01, 0x00, # CMP ACC, 0x0001 (is_prime returns 1 if prime, 0 if not prime)
        $OP_JE, 0x20, 0x00, # JE 0x0020 (psh prime)
        $OP_JMP, 0x00, 0x00 # JMP 0x0000
    )

    # psh prime routine
    Write-Mem -m $mem -start 0x0020 -data @(
        $OP_PUSH, $R0, # PUSH R0
        $OP_JMP, 0x00, 0x00 # JMP 0x0000
    )

    # HLT routine
    Write-Mem -m $mem -start 0x0030 -data @(
        $OP_HLT
    )

    # is_prime routine
    Write-Mem -m $mem -start 0x0100 -data @(
        $OP_CMP_IMM, $R0, 0x02, 0x00, # CMP R0, 0x0002
        $OP_JL, 0x00, 0x1A, # JL 0x1A00 (not_prime) r0 < 2 -> not prime
        $OP_JE, 0x00, 0x1C, # JE 0x1C00 (prime) r0 == 2 -> prime
        $OP_MOV_IMM, $R1, 0x02, 0x00, # R1 = 0x0002
        $OP_JMP, 0x00, 0x05 # JMP 0x0500 (loop)
    )

    # loop routine
    Write-Mem -m $mem -start 0x0500 -data @(
        $OP_MOV, $R2, $R0, # R2 = R0
        $OP_MOD, $R2, $R1, # R2 = R2 % R1
        $OP_CMP_IMM, $R2, 0x00, 0x00, # CMP R2, 0x0000
        $OP_JE, 0x00, 0x1A, # JE 0x1A00 (not_prime) r2 == 0 -> not prime
        $OP_INC, $R1, # R1++
        $OP_CMP, $R1, $R0, # CMP R1, R0
        $OP_JG, 0x00, 0x1C, # JG 0x1C00 (prime) r1 > r0 -> prime
        $OP_JE, 0x00, 0x1C, # JE 0x1C00 (prime) r1 == r0 -> prime
        $OP_JMP, 0x00, 0x05 # JMP 0x0500 (loop)
    )

    # not_prime routine
    Write-Mem -m $mem -start 0x1A00 -data @(
        $OP_MOV_IMM, $ACC, 0x00, 0x00, # ACC = 0x0000
        $OP_RET
    )

    # prime routine
    Write-Mem -m $mem -start 0x1C00 -data @(
        $OP_MOV_IMM, $ACC, 0x01, 0x00, # ACC = 0x0001
        $OP_RET
    )

    # Dump memory
    Dump-Mem -mem $mem -start 0 -end 0x0030
    Read-Host 'Press Enter to continue'

    # Run
    while (($op = Run-Step -cpu $cpu) -ne $OP_HLT) {
        # Write-Host ('Prev. OP: {0:X2} : {1}' -f $op ,(Map-Op-Code-To-String -op $op))
        # Dump-Reg -cpu $cpu
        # Write-Host "Stack: sfs: $($cpu.stackframeSize)"
        # Dump-Mem -mem $mem -start ($cpu.registers[$SP]) -end $STACK_BASE
        # Write-Host "Memory at IP:"
        # Dump-Mem -mem $mem -start $cpu.registers[$IP] -end ($cpu.registers[$IP] + 0x30)
        # Read-Host 'Press Enter to continue'
    }

    # Dump registers
    Dump-Reg -cpu $cpu
    Write-Host "Stack: sfs: $($cpu.stackframeSize)"
    Dump-Mem -mem $mem -start ($cpu.registers[$SP]) -end $STACK_BASE
}

Main
