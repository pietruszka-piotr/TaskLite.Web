namespace TaskLite.Web.Models;

public enum WorkItemStatus { Todo, InProgress, Done }

public class WorkItem
{
    public int Id { get; set; }
    public int ProjectId { get; set; }
    public Project Project { get; set; } = null!;
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public DateOnly? DueDate { get; set; }
    public WorkItemStatus Status { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
