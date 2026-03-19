using Godot;
using System;

public partial class View : Node3D
{
    [Export]
    public Node3D Target { get; set; }

    private Camera3D _camera;

    public override void _Ready()
    {
        _camera = GetNode<Camera3D>("Camera");
    }

    public override void _PhysicsProcess(double delta)
    {
        if (Target == null)
            return;

        // Set position and rotation to target's global position
        GlobalPosition = GlobalPosition.Lerp(Target.GlobalPosition, (float)delta * 4f);
    }
}
