import { Skeleton } from "@/components/ui/skeleton"

export default function Loading() {
    return (

    <div className="grid items-center justify-items-center min-h-screen p-4 pb-20 gap-8 sm:p-10]">
        <main className="flex flex-col gap-8 row-start-2 items-center sm:items-start">
        <Skeleton className="h-12 w-12 rounded-full" />
        <div className="space-y-2">
        <Skeleton className="h-4 w-[250px]" />
        <Skeleton className="h-4 w-[200px]" />
      </div>
      </main>
      </div>

    )
  }