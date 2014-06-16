<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<body>
				<table>
					<xsl:for-each select="//a[contains(@href,'sop://')]">	
						<xsl:variable name="url"><xsl:value-of select="@href"/></xsl:variable>			
						<tr>
							<td><xsl:copy-of select="$url"/></td>
						</tr>
					</xsl:for-each>	
				</table>	
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
