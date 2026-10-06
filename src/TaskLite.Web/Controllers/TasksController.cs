using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TaskLite.Web.Contracts;
using TaskLite.Web.Data;
using TaskLite.Web.Models;

namespace TaskLite.Web.Controllers;

[ApiController]
[Route("api/tasks")]
public class TasksController(TaskLiteDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(int? projectId, WorkItemStatus? status,
        string? search, int page = 1, int pageSize = 20, CancellationToken cancellationToken = default)
    {
        if (page < 1 || page > 100_000 || pageSize < 1 || pageSize > 100 ||
            (status.HasValue && !Enum.IsDefined(status.Value)) || search?.Length > 120)
            return BadRequest(new { error = "Invalid filter or pagination." });
        var query = db.Tasks.AsNoTracking().Include(t => t.Project).AsQueryable();
        if (projectId.HasValue) query = query.Where(t => t.ProjectId == projectId);
        if (status.HasValue) query = query.Where(t => t.Status == status);
        if (!string.IsNullOrWhiteSpace(search)) query = query.Where(t => t.Title.Contains(search.Trim()));
        var total = await query.CountAsync(cancellationToken);
        var tasks = await query.OrderBy(t => t.Id).Skip((page - 1) * pageSize)
            .Take(pageSize).ToListAsync(cancellationToken);
        return Ok(new { items = tasks.Select(TaskResponse.From), total, page, pageSize });
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id, CancellationToken cancellationToken)
    {
        var task = await db.Tasks.AsNoTracking().Include(t => t.Project)
            .SingleOrDefaultAsync(t => t.Id == id, cancellationToken);
        return task is null ? NotFound() : Ok(TaskResponse.From(task));
    }

    [HttpPost]
    public async Task<IActionResult> Create(SaveTaskRequest request, CancellationToken cancellationToken)
    {
        var project = await db.Projects.FindAsync([request.ProjectId], cancellationToken);
        if (project is null) return BadRequest(new { error = "Project does not exist." });
        if (string.IsNullOrWhiteSpace(request.Title)) return BadRequest(new { error = "Title cannot be blank." });
        var task = new WorkItem { CreatedAtUtc = DateTime.UtcNow, Project = project };
        Apply(request, task);
        db.Tasks.Add(task);
        await db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = task.Id }, TaskResponse.From(task));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, SaveTaskRequest request, CancellationToken cancellationToken)
    {
        var task = await db.Tasks.FindAsync([id], cancellationToken);
        if (task is null) return NotFound();
        var project = await db.Projects.FindAsync([request.ProjectId], cancellationToken);
        if (project is null) return BadRequest(new { error = "Project does not exist." });
        if (string.IsNullOrWhiteSpace(request.Title)) return BadRequest(new { error = "Title cannot be blank." });
        task.Project = project;
        Apply(request, task);
        await db.SaveChangesAsync(cancellationToken);
        return Ok(TaskResponse.From(task));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var task = await db.Tasks.FindAsync([id], cancellationToken);
        if (task is null) return NotFound();
        db.Tasks.Remove(task);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private static void Apply(SaveTaskRequest request, WorkItem task)
    {
        task.ProjectId = request.ProjectId;
        task.Title = request.Title.Trim();
        task.Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        task.DueDate = request.DueDate;
        task.Status = request.Status;
    }
}
