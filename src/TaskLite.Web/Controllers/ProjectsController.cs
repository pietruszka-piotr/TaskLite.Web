using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using TaskLite.Web.Contracts;
using TaskLite.Web.Data;
using TaskLite.Web.Models;

namespace TaskLite.Web.Controllers;

[ApiController]
[Route("api/projects")]
public class ProjectsController(TaskLiteDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await db.Projects.AsNoTracking().OrderBy(p => p.Name)
            .Select(p => new { p.Id, p.Name }).ToListAsync(cancellationToken));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id, CancellationToken cancellationToken)
    {
        var project = await db.Projects.AsNoTracking().SingleOrDefaultAsync(p => p.Id == id, cancellationToken);
        return project is null ? NotFound() : Ok(new { project.Id, project.Name });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateProjectRequest request, CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        if (name.Length == 0) return BadRequest(new { error = "Project name cannot be blank." });
        var project = new Project { Name = name };
        db.Projects.Add(project);
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
        {
            return Conflict(new { error = "A project with this name already exists." });
        }
        return CreatedAtAction(nameof(GetById), new { id = project.Id }, new { project.Id, project.Name });
    }
}
