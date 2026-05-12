using System;
using Microsoft.Xrm.Sdk;

namespace DataversePluginTemplate
{
    public class SamplePlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            ITracingService tracingService =
                (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            IPluginExecutionContext context =
                (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

            tracingService.Trace("SamplePlugin: Execute started");

            if (context.Depth > 2)
            {
                tracingService.Trace("SamplePlugin: Depth check failed. Exiting to prevent recursion.");
                return;
            }

            try
            {
                if (!(context.InputParameters.Contains("Target") && context.InputParameters["Target"] is Entity))
                {
                    tracingService.Trace("SamplePlugin: Target entity not found. Exiting.");
                    return;
                }

                Entity target = (Entity)context.InputParameters["Target"];

                if (context.MessageName.Equals("Create", StringComparison.OrdinalIgnoreCase) ||
                    context.MessageName.Equals("Update", StringComparison.OrdinalIgnoreCase))
                {
                    if (target.Contains("YOUR_PUBLISHER_PREFIX_name"))
                    {
                        string name = target.GetAttributeValue<string>("YOUR_PUBLISHER_PREFIX_name");

                        if (string.IsNullOrWhiteSpace(name))
                        {
                            throw new InvalidPluginExecutionException("Name cannot be empty.");
                        }
                    }

                    tracingService.Trace($"SamplePlugin: {context.MessageName} validation completed.");
                }
                else
                {
                    tracingService.Trace($"SamplePlugin: Unsupported message '{context.MessageName}'. Exiting.");
                }
            }
            catch (InvalidPluginExecutionException)
            {
                throw;
            }
            catch (Exception ex)
            {
                tracingService.Trace($"SamplePlugin: Error - {ex.Message}");
                throw new InvalidPluginExecutionException($"SamplePlugin failed: {ex.Message}", ex);
            }
        }
    }
}
