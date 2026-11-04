import { extractArtifacts, writeManifest } from "./scripts/extract-artifacts";
extractArtifacts("bytecodes");
writeManifest();
