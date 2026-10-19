import { latestVersion } from "@/lib/shared";
import { redirect } from "next/navigation";

export default async function ApiReferencePage() {
  redirect("/docs" + latestVersion.url + "/api_reference");
}
