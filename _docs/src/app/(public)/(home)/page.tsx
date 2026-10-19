import Footer from "./_components/footer";
import FinalBanner from "./_components/final_banner";
import IntergrationMatrix from "./_components/integration_matrix";
import { HeroSection } from "./_components/hero_section";
import { PillarCards } from "./_components/pillar_cards";

import type { Metadata, ResolvingMetadata } from "next";

type Props = {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
};

export async function generateMetadata(
  { params, searchParams }: Props,
  parent: ResolvingMetadata,
): Promise<Metadata> {
  return {
    description:
      "Learn about our Godot addons, their purpose, features, and development. Discover tools and resources designed to enhance your Godot game development workflow.",
  };
}

export default function HomePage() {
  return (
    <div className="flex flex-col justify-center text-center flex-1">
      <HeroSection />
      <PillarCards />
      <IntergrationMatrix csharpCode={csharpCode} gdscriptCode={gdscriptCode} />
      <FinalBanner />
      <Footer />
    </div>
  );
}

const gdscriptCode = `func _ready() -> void:
    # Initialize and register custom free camera commands.
	_register_commands()

func _register_commands() -> void:
	DCKit.register_def(
		DCDefinition
		.new(
			"toggle_free_cam",
			func(_ctx: DCContext) -> DCResult:
				toggle_free_cam()

				DCKit.hide_console()
				return DCResult.ok("Free cam [b]%s[/b]." % ("on" if free_cam else "off")),
			"Toggles the free-flying camera.",
			[],
		)
		.alias("tfc")
	)

	DCKit.register_def(
		DCDefinition
		.new(
			"set_free_cam",
			func(ctx: DCContext) -> DCResult:
				var enabled: bool = (await ctx.arg(0)).value.as_bool()

				if free_cam != enabled:
					toggle_free_cam()

				return DCResult.ok("Free cam [b]%s[/b]." % ("on" if free_cam else "off")),
			"Enables or disables the free-flying camera.",
			[DCDefinition.Param.new("switch").describe("on or off")],
		)
		.alias("sfc")
	)
`;

const csharpCode = `using Godot;

public override void _Ready()
{
    // Initialize and register custom free camera commands.
    RegisterCommands();
}

private void RegisterCommands()
{
    DCKit.RegisterDef(
        new DCDefinition(
            "toggle_free_cam",
            (DCContext ctx) =>
            {
                ToggleFreeCam();
                DCKit.HideConsole();

                return DCResult.Ok(
                    $"Free cam [b]{(freeCam ? "on" : "off")}[/b]."
                );
            },
            "Toggles the free-flying camera.",
            Array.Empty<DCDefinition.Param>()
        ).Alias("tfc")
    );

    DCKit.RegisterDef(
        new DCDefinition(
            "set_free_cam",
            async (DCContext ctx) =>
            {
                bool enabled = (await ctx.Arg(0)).Value.AsBool();

                if (freeCam != enabled)
                    ToggleFreeCam();

                DCKit.HideConsole();

                return DCResult.Ok(
                    $"Free cam [b]{(freeCam ? "on" : "off")}[/b]."
                );
            },
            "Enables or disables the free-flying camera.",
            new[]
            {
                new DCDefinition.Param("switch")
                    .Describe("on or off")
            }
        ).Alias("sfc")
    );
}
`;
