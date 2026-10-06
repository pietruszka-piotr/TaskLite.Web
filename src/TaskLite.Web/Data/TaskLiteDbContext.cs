using Microsoft.EntityFrameworkCore;
using TaskLite.Web.Models;

namespace TaskLite.Web.Data;

public class TaskLiteDbContext(DbContextOptions<TaskLiteDbContext> options) : DbContext(options)
{
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<WorkItem> Tasks => Set<WorkItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Project>(entity =>
        {
            entity.Property(p => p.Name).HasMaxLength(100).IsRequired();
            entity.HasIndex(p => p.Name).IsUnique();
        });
        modelBuilder.Entity<WorkItem>(entity =>
        {
            entity.Property(t => t.Title).HasMaxLength(120).IsRequired();
            entity.Property(t => t.Description).HasMaxLength(1000);
            entity.Property(t => t.Status).HasConversion<string>().HasMaxLength(20);
            entity.HasIndex(t => new { t.ProjectId, t.Status, t.DueDate });
            entity.HasOne(t => t.Project).WithMany(p => p.Tasks)
                .HasForeignKey(t => t.ProjectId).OnDelete(DeleteBehavior.Restrict);
        });
    }
}
