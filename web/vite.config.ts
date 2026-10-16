import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig(({ mode }) => {
    // Vite publishes every VITE_* variable of the build environment inside the bundle (a library even pulls in the
    // whole import.meta.env object), so a login token there would be public. Refuse to build rather than leak it.
    if (mode === "production" && loadEnv(mode, process.cwd(), "VITE_").VITE_DEV_TOKEN) {
        throw new Error("VITE_DEV_TOKEN is set for a production build and would be published in the bundle. Unset it.");
    }

    return {
    plugins: [react()],
    resolve: {
        alias: {
            "@": path.resolve(__dirname, "./src"),
        },
    },
    build: {
        rollupOptions: {
            output: {
                manualChunks: {
                    "vendor-react": ["react", "react-dom", "react-router-dom"],
                    "vendor-ui": ["@radix-ui/react-dialog", "@radix-ui/react-select", "@radix-ui/react-tabs", "@radix-ui/react-alert-dialog", "@radix-ui/react-dropdown-menu"],
                    "vendor-misc": ["axios", "jotai", "lucide-react", "react-hook-form"],
                },
            },
        },
    },
};
});
