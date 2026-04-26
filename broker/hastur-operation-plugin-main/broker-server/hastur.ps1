#!/usr/bin/env pwsh
# Hastur CLI - Godot Editor Remote Execution Tool
# Usage: hastur.ps1 <command> [options]

param(
    [Parameter(Position=0)]
    [ValidateSet("exec", "health", "executors", "watch")]
    [string]$Command = "health",

    [Parameter(Position=1)]
    [string]$Code = "",

    [string]$ExecutorId = "",
    [string]$ProjectName = "",
    [int]$Timeout = 30000,
    [string]$Token = "995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7",
    [string]$BrokerHost = "localhost",
    [int]$Port = 5302
)

$ErrorActionPreference = "Continue"

function Invoke-HasturApi {
    param([string]$Endpoint, [string]$Method = "GET", [hashtable]$Body = @{})
    $url = "http://${BrokerHost}:${Port}${Endpoint}"
    $headers = @{
        "Authorization" = "Bearer ${Token}"
        "Content-Type" = "application/json"
    }
    $params = @{
        Uri = $url
        Headers = $headers
        Method = $Method
        TimeoutSec = 60
    }
    if ($Body.Count -gt 0) {
        $params.Body = ($Body | ConvertTo-Json -Compress)
    }
    try {
        if ($Method -eq "GET") {
            return Invoke-RestMethod @params
        } else {
            $response = Invoke-WebRequest @params
            return $response.Content | ConvertFrom-Json
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

switch ($Command) {
    "health" {
        Write-Host "Checking broker health..." -ForegroundColor Cyan
        $result = Invoke-HasturApi -Endpoint "/api/health"
        if ($result) {
            Write-Host "`nBroker Status:" -ForegroundColor Green
            Write-Host "  Version:   $($result.data.version)"
            Write-Host "  TCP Port:  $($result.data.tcp_port)"
            Write-Host "  HTTP Port: $($result.data.http_port)"
            Write-Host "  Executors: $($result.data.executors_connected)"
            if ($result.data.executors) {
                Write-Host "`nConnected Executors:"
                foreach ($ex in $result.data.executors) {
                    Write-Host "  - $($ex.project_name) ($($ex.id))" -ForegroundColor Yellow
                    Write-Host "    Status: $($ex.status), Uptime: $($ex.uptime_seconds)s"
                }
            }
        }
    }

    "executors" {
        Write-Host "Listing executors..." -ForegroundColor Cyan
        $result = Invoke-HasturApi -Endpoint "/api/executors"
        if ($result) {
            if ($result.data.Count -eq 0) {
                Write-Host "No executors connected." -ForegroundColor Yellow
            } else {
                Write-Host "`nExecutors:" -ForegroundColor Green
                foreach ($ex in $result.data) {
                    Write-Host "  ID:         $($ex.id)"
                    Write-Host "  Project:    $($ex.project_name)"
                    Write-Host "  Path:       $($ex.project_path)"
                    Write-Host "  PID:        $($ex.editor_pid)"
                    Write-Host "  Godot:      $($ex.editor_version)"
                    Write-Host "  Connected:  $($ex.connected_at)"
                    Write-Host ""
                }
            }
        }
    }

    "exec" {
        if ([string]::IsNullOrEmpty($Code)) {
            Write-Host "Error: Code required for exec command" -ForegroundColor Red
            Write-Host "Usage: hastur.ps1 exec 'print(42)' [-ExecutorId <id>] [-Timeout <ms>]"
            exit 1
        }

        $body = @{
            code = $Code
            timeout_ms = $Timeout
        }

        if (-not [string]::IsNullOrEmpty($ExecutorId)) {
            $body.executor_id = $ExecutorId
        } elseif (-not [string]::IsNullOrEmpty($ProjectName)) {
            $body.project_name = $ProjectName
        } else {
            Write-Host "Error: Either -ExecutorId or -ProjectName required" -ForegroundColor Red
            exit 1
        }

        Write-Host "Executing..." -ForegroundColor Cyan
        Write-Host "Code: $Code" -ForegroundColor Gray
        Write-Host ""

        $result = Invoke-HasturApi -Endpoint "/api/execute" -Method "POST" -Body $body

        if ($result) {
            if ($result.success) {
                Write-Host "Success!" -ForegroundColor Green
                if ($result.data.compile_success) {
                    Write-Host "  Compiled: OK" -ForegroundColor Green
                } else {
                    Write-Host "  Compile Error: $($result.data.compile_error)" -ForegroundColor Red
                }
                if ($result.data.run_success) {
                    Write-Host "  Executed: OK" -ForegroundColor Green
                } else {
                    Write-Host "  Run Error: $($result.data.run_error)" -ForegroundColor Red
                }
                if ($result.data.outputs.Count -gt 0) {
                    Write-Host "`nOutput:" -ForegroundColor Yellow
                    foreach ($output in $result.data.outputs) {
                        Write-Host "  $($output[1])"
                    }
                }
            } else {
                Write-Host "Failed: $($result.error)" -ForegroundColor Red
                if ($result.hint) {
                    Write-Host "Hint: $($result.hint)" -ForegroundColor Gray
                }
            }
        }
    }

    "watch" {
        Write-Host "Watch mode not yet implemented. Use exec command in a loop." -ForegroundColor Yellow
    }
}
