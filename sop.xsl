<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<body>
				<table>
					<tr>
						<th>URL</th>
						<th>Quality</th>						
						<th>Language</th>
					</tr>
					<xsl:for-each select="//a[contains(@href,'sop://')]">	
						<xsl:variable name="url"><xsl:value-of select="@href"/></xsl:variable>			
						<tr>
							<td><a href="{$url}"><xsl:copy-of select="$url"/></a>,</td>
							<td><xsl:value-of select="../preceding-sibling::td[3]/div/text()"/>,</td>
							<td><xsl:value-of select="../../../../following-sibling::td[1]/span[@class='date']/b"/></td>	
						</tr>
					</xsl:for-each>	
				</table>	
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
