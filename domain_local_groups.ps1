param (
	[string] $siteurl = "",
	[string] $groupscsv = "",
	[string] $debugmode = ""
)

if ($siteurl -eq "")
{
	$siteurl = Read-Host "Site Url";
}

if ($groupscsv -ne "") 
{
	$path = Split-Path -parent $MyInvocation.MyCommand.Definition
	$starttime = (Get-Date -UFormat "%Y_%m_%d_%I_%M_%S_%p").ToString()
	Start-Transcript "$path\Domain_Local_Group_Cloning_$starttime.txt"

	$adgroups = ipcsv $groupscsv

	Write-Host -ForegroundColor green "Domain local groups loaded from -> $groupscsv"

	if ((Get-PSSnapin -Name "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null)
	{
		Add-PSSnapin "Microsoft.SharePoint.PowerShell"
	}

	$sites = Get-SPSite $siteurl

	foreach ($site in $sites) 
	{
		$currentsiteurl = $site.Url
		Write-Host -ForegroundColor green "`r`nStarted crawling SharePoint Site at $starttime with url -> $currentsiteurl"

		foreach ($web in $site.AllWebs)
		{
			if ($web.HasUniqueRoleAssignments)
			{
				$adgroups | foreach { 
					$group = $_.SamAccountName;

					$webroleassignment = $web.RoleAssignments | where { $_.Member.Name -eq $group }

					if ($webroleassignment -ne $null -and $webroleassignment.Member.UserLogin -ne $null -and $debugmode -eq "")
					{
						$newdomainlocalaccount = $web.EnsureUser("$group DL")
						$web.Update()

						if ($newdomainlocalaccount -ne $null)
						{
							$newroleassignment = New-Object Microsoft.SharePoint.SPRoleAssignment($newdomainlocalaccount)

							foreach($roledefinition in $webroleassignment.RoleDefinitionBindings) 
							{
								if ($roledefinition.Name -ne "Limited Access")
								{
								   $newroledefinition = $web.RoleDefinitions[$roledefinition.Name]

								   if ($newroledefinition -ne $null)
								   {
									   $newroleassignment.RoleDefinitionBindings.Add($newroledefinition)
								   }
								}
							}

							if ($newroleassignment.RoleDefinitionBindings.Count -gt 0)
							{
								$web.RoleAssignments.Add($newroleassignment)
								$web.Update()
							}

							Write-Host -ForegroundColor green "`r`nCreated $newdomainlocalaccount for web -> " + $web.Url
						}
					}
				}			
			}

			foreach ($list in $web.Lists)
			{
				if ($list.HasUniqueRoleAssignments)
				{
					$adgroups | foreach { 
						$group = $_.SamAccountName;

						$listroleassignment = $list.RoleAssignments | where { $_.Member.Name -eq $group }

						if ($listroleassignment -ne $null -and $listroleassignment.Member.UserLogin -ne $null -and $debugmode -eq "")
						{
							$newdomainlocalaccount = $web.EnsureUser("$group DL")
							$web.Update()

							if ($newdomainlocalaccount -ne $null)
							{
								$newroleassignment = New-Object Microsoft.SharePoint.SPRoleAssignment($newdomainlocalaccount)

								foreach($roledefinition in $listroleassignment.RoleDefinitionBindings) 
								{
									if ($roledefinition.Name -ne "Limited Access")
									{
									   $newroledefinition = $web.RoleDefinitions[$roledefinition.Name]

									   if ($newroledefinition -ne $null)
									   {
										   $newroleassignment.RoleDefinitionBindings.Add($newroledefinition)
									   }
									}
								}

								if ($newroleassignment.RoleDefinitionBindings.Count -gt 0)
								{
									$list.RoleAssignments.Add($newroleassignment)
									$list.Update()
								}

								$currentlisturl = $list.ParentWeb.Url + "/" + $list.RootFolder.Url
								Write-Host -ForegroundColor magenta "`r`nCreated $newdomainlocalaccount for list -> $currentlisturl"
							}
						}
					}		
				}

				$spquery = New-Object Microsoft.SharePoint.SPQuery
				$spquery.ViewAttributes = "Scope='Recursive'"
				$spquery.RowLimit = 2000
				$caml = "<OrderBy Override='TRUE'><FieldRef Name='ID'/></OrderBy>"
				$spquery.Query = $caml 

				do
				{
					$listitems = $list.GetItems($spQuery)
					$spquery.ListItemCollectionPosition = $listitems.ListItemCollectionPosition

					foreach ($listitem in $listitems)
					{
						if ($listitem.HasUniqueRoleAssignments)
						{
							$adgroups | foreach { 
								$group = $_.SamAccountName;

								$listitemroleassignment = $listitem.RoleAssignments | where { $_.Member.Name -eq $group }

								if ($listitemroleassignment -ne $null -and $listitemroleassignment.Member.UserLogin -ne $null -and $debugmode -eq "")
								{
									$newdomainlocalaccount = $web.EnsureUser("$group DL")
									$web.Update()

									if ($newdomainlocalaccount -ne $null)
									{
										$newroleassignment = New-Object Microsoft.SharePoint.SPRoleAssignment($newdomainlocalaccount)

										foreach($roledefinition in $listitemroleassignment.RoleDefinitionBindings) 
										{
											if ($roledefinition.Name -ne "Limited Access")
											{
											   $newroledefinition = $web.RoleDefinitions[$roledefinition.Name]

											   if ($newroledefinition -ne $null)
											   {
												   $newroleassignment.RoleDefinitionBindings.Add($newroledefinition)
											   }
											}
										}

										if ($newroleassignment.RoleDefinitionBindings.Count -gt 0)
										{
											$listitem.RoleAssignments.Add($newroleassignment)
											$listitem.Update()
										}

										$currentlistitemurl = $listitem.Web.Url + "/" + $listitem.Url
										Write-Host -ForegroundColor yellow "`r`nCreated $newdomainlocalaccount for list item -> $currentlistitemurl"
									}
								}
							}		
						}
					}
				}
				while ($spQuery.ListItemCollectionPosition -ne $null)
			}

			$web.Dispose()
		}

		$site.Dispose()
	}

	Stop-Transcript

	$endtime = (Get-Date -UFormat "%Y_%m_%d_%I_%M_%S_%p").ToString()
	Write-Host -ForegroundColor green "`r`nCloning domain local groups completed at $endtime!"
}