using System.ComponentModel.DataAnnotations;
using TaskLite.Web.Models;

namespace TaskLite.Web.Contracts;

public record CreateProjectRequest([Required, StringLength(100)] string Name);

public record SaveTaskRequest(
    [Range(1, int.MaxValue)] int ProjectId,
    [Required, StringLength(120)] string Title,
    [StringLength(1000)] string? Description,
    DateOnly? DueDate,
    [EnumDataType(typeof(WorkItemStatus))] WorkItemStatus Status);

public record TaskResponse(int Id, int ProjectId, string ProjectName, string Title,
    string? Description, DateOnly? DueDate, WorkItemStatus Status, DateTime CreatedAtUtc)
{
    public static TaskResponse From(WorkItem task) => new(task.Id, task.ProjectId,
        task.Project.Name, task.Title, task.Description, task.DueDate, task.Status, task.CreatedAtUtc);
}
