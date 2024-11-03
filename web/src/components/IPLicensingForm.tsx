"use client"
import {
  useState
} from "react"
import {
  toast
} from "sonner"
import {
  useForm
} from "react-hook-form"
import {
  zodResolver
} from "@hookform/resolvers/zod"
import * as z from "zod"
import {
  cn
} from "@/lib/utils"
import {
  Button
} from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList
} from "@/components/ui/command"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import {
  Check,
  ChevronsUpDown
} from "lucide-react"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Textarea
} from "@/components/ui/textarea"
import {
  Input
} from "@/components/ui/input"

const formSchema = z.object({
  IPID: z.string(),
  type: z.string(),
  description: z.string(),
  field: z.string().optional(),
  geographical: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  termsURL: z.string().optional(),
  financialTerms: z.string().optional(),
  financialObs: z.string().optional(),
  currency: z.string().optional(),
  initpay: z.number().optional(),
  installments: z.number().min(0).max(0).optional(),
  recurringPay: z.string().optional(),
  royaltiesCriteria: z.string().optional(),
  royaltiesvalue: z.number().min(0).max(100).optional()
});

export default function IPLicensingForm() {
  const languages = [{
      label: "English",
      value: "en"
    },
    {
      label: "French",
      value: "fr"
    },
    {
      label: "German",
      value: "de"
    },
    {
      label: "Spanish",
      value: "es"
    },
    {
      label: "Portuguese",
      value: "pt"
    },
    {
      label: "Russian",
      value: "ru"
    },
    {
      label: "Japanese",
      value: "ja"
    },
    {
      label: "Korean",
      value: "ko"
    },
    {
      label: "Chinese",
      value: "zh"
    },
  ] as
  const;
  const form = useForm < z.infer < typeof formSchema >> ({
    resolver: zodResolver(formSchema),

  })

  function onSubmit(values: z.infer < typeof formSchema > ) {
    try {
      console.log(values);
      toast(
        <pre className="mt-2 w-[340px] rounded-md bg-slate-950 p-4">
          <code className="text-white">{JSON.stringify(values, null, 2)}</code>
        </pre>
      );
    } catch (error) {
      console.error("Form submission error", error);
      toast.error("Failed to submit the form. Please try again.");
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8 max-w-3xl mx-auto py-10">
        <FormField
          control={form.control}
          name="IPID"
          render={({ field }) => (
            <FormItem className="flex flex-col">
              <FormLabel>Intellectual Property</FormLabel>
              <Popover>
                <PopoverTrigger asChild>
                  <FormControl>
                    <Button
                      variant="outline"
                      role="combobox"
                      className={cn(
                        "w-[200px] justify-between",
                        !field.value && "text-muted-foreground"
                      )}
                      
                    >
                      {field.value
                        ? languages.find(
                            (language) => language.value === field.value
                          )?.label
                        : "Select language"}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </Button>
                  </FormControl>
                </PopoverTrigger>
                <PopoverContent className="w-[200px] p-0">
                  <Command>
                    <CommandInput placeholder="Search language..." />
                    <CommandList>
                      <CommandEmpty>No language found.</CommandEmpty>
                      <CommandGroup>
                        {languages.map((language) => (
                          <CommandItem
                            value={language.label}
                            key={language.value}
                            onSelect={() => {
                              form.setValue("IPID", language.value);
                            }}
                          >
                            <Check
                              className={cn(
                                "mr-2 h-4 w-4",
                                language.value === field.value
                                  ? "opacity-100"
                                  : "opacity-0"
                              )}
                            />
                            {language.label}
                          </CommandItem>
                        ))}
                      </CommandGroup>
                    </CommandList>
                  </Command>
                </PopoverContent>
              </Popover>
              <FormDescription>Select your registered IP to license</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="type"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Type</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a type" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="m@example.com">m@example.com</SelectItem>
                  <SelectItem value="m@google.com">m@google.com</SelectItem>
                  <SelectItem value="m@support.com">m@support.com</SelectItem>
                </SelectContent>
              </Select>
                <FormDescription>Choose the type of licensing</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Textarea
                  placeholder="Description"
                  className="resize-none"
                  {...field}
                />
              </FormControl>
              <FormDescription>Set the licensing description.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="field"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Field of use</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. Film Soundtrack"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>You can define a field of use.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="geographical"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Geographical area</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. Brazil"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>Define a geographic area for your license.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="startDate"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Start Date</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. 2025"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>Licensing start date</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="endDate"
          render={({ field }) => (
            <FormItem>
              <FormLabel>End Date</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. 12/31/2049"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>Licensing end date</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="termsURL"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Licensing Terms</FormLabel>
              <FormControl>
                <Input 
                placeholder="https://"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>External link to licensing terms.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="financialTerms"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Financial Terms</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="m@example.com">m@example.com</SelectItem>
                  <SelectItem value="m@google.com">m@google.com</SelectItem>
                  <SelectItem value="m@support.com">m@support.com</SelectItem>
                </SelectContent>
              </Select>
                <FormDescription>Choose the financial compensation model</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="financialObs"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Financial observations</FormLabel>
              <FormControl>
                <Textarea
                  placeholder="e.g. Recurring payment for streaming content."
                  className="resize-none"
                  {...field}
                />
              </FormControl>
              <FormDescription>You can add notes and extra terms about the financial conditions of the license.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="currency"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Payment Currency</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="m@example.com">m@example.com</SelectItem>
                  <SelectItem value="m@google.com">m@google.com</SelectItem>
                  <SelectItem value="m@support.com">m@support.com</SelectItem>
                </SelectContent>
              </Select>
                <FormDescription>Select which cryptocurrency you want to use in the transaction.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="initpay"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Initial Payment</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. 1"
                
                type="number"
                {...field} />
              </FormControl>
              <FormDescription>Payment to be made upfront.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="installments"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Number of installments</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. 12"
                
                type="number"
                {...field} />
              </FormControl>
              <FormDescription>You can set a number of installments.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="recurringPay"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Recurring Payment</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="m@example.com">m@example.com</SelectItem>
                  <SelectItem value="m@google.com">m@google.com</SelectItem>
                  <SelectItem value="m@support.com">m@support.com</SelectItem>
                </SelectContent>
              </Select>
                <FormDescription>Set the frequency of the recurring payment.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="royaltiesCriteria"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Royalties Criteria</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. Sales Profit"
                
                type=""
                {...field} />
              </FormControl>
              <FormDescription>Define a criterion for the value of royalties.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="royaltiesvalue"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Royalties Value</FormLabel>
              <FormControl>
                <Input 
                placeholder="e.g. 10%"
                
                type="number"
                {...field} />
              </FormControl>
              <FormDescription>Set a value for royalties.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit">Submit</Button>
      </form>
    </Form>
  )
}