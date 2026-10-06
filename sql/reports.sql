-- Run after adding projects and tasks. All project rows appear, including empty projects.
SELECT p.Id, p.Name,
       COUNT(t.Id) AS TotalTasks,
       SUM(CASE WHEN t.Status = 'Done' THEN 1 ELSE 0 END) AS CompletedTasks
FROM dbo.Projects AS p
LEFT JOIN dbo.Tasks AS t ON t.ProjectId = p.Id
GROUP BY p.Id, p.Name
ORDER BY p.Name;

DECLARE @Today date = CONVERT(date, GETUTCDATE());
SELECT p.Name, t.Title, t.DueDate, t.Status
FROM dbo.Tasks AS t
INNER JOIN dbo.Projects AS p ON p.Id = t.ProjectId
WHERE t.Status <> 'Done' AND t.DueDate < @Today
ORDER BY t.DueDate, t.Id;
