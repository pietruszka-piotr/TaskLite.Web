param([string]$BaseUrl = 'http://localhost:8080')
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$createdProjects = [System.Collections.Generic.List[object]]::new()
$createdTasks = [System.Collections.Generic.List[object]]::new()
$checksPassed = $false

function Request([string]$Method, [string]$Path, $Body, [int]$ExpectedStatus = 200) {
    $parameters = @{ Uri = "$BaseUrl$Path"; Method = $Method; SkipHttpErrorCheck = $true }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = ConvertTo-Json $Body -Depth 5
    }
    $response = Invoke-WebRequest @parameters
    if ([int]$response.StatusCode -ne $ExpectedStatus) {
        throw "$Method $Path expected $ExpectedStatus, received $($response.StatusCode): $($response.Content)"
    }
    Write-Host "PASS $Method $Path -> $ExpectedStatus"
    if ($response.Content) { return ($response.Content | ConvertFrom-Json) }
}

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function Assert-Order($Result, [int[]]$ExpectedIds, [string]$Message) {
    $actualIds = @($Result.items | ForEach-Object { $_.id })
    Assert (($actualIds -join ',') -eq ($ExpectedIds -join ',')) $Message
}

function New-TestTask([int]$ProjectId, [string]$Title, [string]$Status, $DueDate) {
    $task = Request 'POST' '/api/tasks' @{
        projectId = $ProjectId
        title = $Title
        description = $null
        dueDate = $DueDate
        status = $Status
    } 201
    $createdTasks.Add($task)
    return $task
}

try {
    Request 'GET' '/health' $null | Out-Null
    $project = Request 'POST' '/api/projects' @{ name = "Sorting-$([Guid]::NewGuid().ToString('N'))" } 201
    $createdProjects.Add($project)
    $otherProject = Request 'POST' '/api/projects' @{ name = "Sorting-other-$([Guid]::NewGuid().ToString('N'))" } 201
    $createdProjects.Add($otherProject)

    # Creation order differs from deadline order; equal deadlines must use ascending IDs.
    $undated = New-TestTask $project.id 'Sorting match undated' 'Todo' $null
    $later = New-TestTask $project.id 'Sorting match later' 'Todo' '2026-12-10'
    $sameDateFirst = New-TestTask $project.id 'Sorting match equal first' 'Todo' '2026-12-05'
    $sameDateSecond = New-TestTask $project.id 'Sorting match equal second' 'Done' '2026-12-05'
    $earliest = New-TestTask $project.id 'Sorting other earliest' 'InProgress' '2026-12-01'
    New-TestTask $otherProject.id 'Sorting match other project' 'Todo' '2026-11-01' | Out-Null

    $baseQuery = "/api/tasks?projectId=$($project.id)"
    $defaultOrder = Request 'GET' $baseQuery $null
    Assert ($defaultOrder.total -eq 5) 'The project filter should exclude the task in the other project.'
    Assert-Order $defaultOrder @($undated.id, $later.id, $sameDateFirst.id, $sameDateSecond.id, $earliest.id) 'The default order should remain oldest first.'

    $oldest = Request 'GET' ($baseQuery + '&sort=oldest') $null
    Assert-Order $oldest @($undated.id, $later.id, $sameDateFirst.id, $sameDateSecond.id, $earliest.id) 'Explicit oldest order is incorrect.'

    $newest = Request 'GET' ($baseQuery + '&sort=newest') $null
    Assert-Order $newest @($earliest.id, $sameDateSecond.id, $sameDateFirst.id, $later.id, $undated.id) 'Newest order should reverse creation order.'

    $byDueDate = Request 'GET' ($baseQuery + '&sort=dueDate') $null
    Assert-Order $byDueDate @($earliest.id, $sameDateFirst.id, $sameDateSecond.id, $later.id, $undated.id) 'Deadline order should put null last and break equal-date ties by ascending ID.'

    $secondPage = Request 'GET' ($baseQuery + '&sort=dueDate&pageSize=1&page=2') $null
    Assert-Order $secondPage @($sameDateFirst.id) 'Sorting must happen before pagination.'
    Assert ($secondPage.total -eq 5 -and $secondPage.page -eq 2 -and $secondPage.pageSize -eq 1) 'Pagination metadata is incorrect.'

    $search = [Uri]::EscapeDataString('Sorting match')
    $filtered = Request 'GET' ($baseQuery + '&sort=dueDate&status=Todo&search=' + $search) $null
    Assert ($filtered.total -eq 3) 'Sorting should preserve status, search and project filters.'
    Assert-Order $filtered @($sameDateFirst.id, $later.id, $undated.id) 'Filtered deadline order is incorrect.'

    $equalDates = Request 'GET' ($baseQuery + '&sort=dueDate&search=equal') $null
    Assert-Order $equalDates @($sameDateFirst.id, $sameDateSecond.id) 'Equal deadlines should be ordered by ascending ID.'
    $equalDatesPageTwo = Request 'GET' ($baseQuery + '&sort=dueDate&search=equal&pageSize=1&page=2') $null
    Assert-Order $equalDatesPageTwo @($sameDateSecond.id) 'Equal deadlines should remain stable across pages.'

    Request 'GET' ($baseQuery + '&sort=unknown') $null 400 | Out-Null
    $checksPassed = $true
} finally {
    $cleanupErrors = @()
    # Remove only this run's records, tasks before projects to respect the foreign key.
    $cleanupPaths = @($createdTasks | ForEach-Object { "/api/tasks/$($_.id)" }) + @($createdProjects | ForEach-Object { "/api/projects/$($_.id)" })
    foreach ($path in $cleanupPaths) {
        try {
            $response = Invoke-WebRequest -Uri "$BaseUrl$path" -Method Delete -SkipHttpErrorCheck
            if ([int]$response.StatusCode -notin @(204, 404)) {
                throw "DELETE $path returned $($response.StatusCode): $($response.Content)"
            }
        } catch {
            $cleanupErrors += $_.Exception.Message
        }
    }
    if ($cleanupErrors.Count -gt 0) {
        $cleanupMessage = "Sorting cleanup failed: $($cleanupErrors -join '; ')"
        if ($checksPassed) { throw $cleanupMessage }
        Write-Warning $cleanupMessage
    }
}
Write-Host 'All sorting checks passed against the configured database.'
