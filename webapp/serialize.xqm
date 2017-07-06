xquery version "3.1";
(: part of Guid-O-Matic 2.0 https://github.com/baskaufs/guid-o-matic . You are welcome to reuse or hack in any way :)

module namespace serialize = 'http://bioimages.vanderbilt.edu/xqm/serialize';

import module namespace propvalue = 'http://bioimages.vanderbilt.edu/xqm/propvalue' at 'propvalue.xqm';

(: These two functions copied from FunctX http://www.xqueryfunctions.com/ :)

declare function serialize:substring-after-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   replace ($arg,concat('^.*',serialize:escape-for-regex($delim)),'')
 } ;

 declare function serialize:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;
(:--------------------------------------------------------------------------------------------------:)

declare function serialize:main-db($id,$serialization,$singleOrDump,$db)
{

let $outputToFile := "false"

let $constants := fn:collection($db)//constants/record
let $domainRoot := $constants//domainRoot/text()
let $outputDirectory := $constants//outputDirectory/text()
let $baseIriColumn := $constants//baseIriColumn/text()
let $modifiedColumn := $constants//modifiedColumn/text()
let $outFileNameAfter := $constants//outFileNameAfter/text()

let $columnInfo := fn:collection($db)//column-index/record
let $namespaces := fn:collection($db)//namespaces/record
let $classes := fn:collection($db)//base-classes/record
let $linkedClasses := fn:collection($db)//linked-classes/record
let $metadata := fn:collection($db)//metadata/record
let $linkedMetadata := fn:collection($db)//linked-metadata/file

return serialize:generate-entire-document($id,$linkedMetadata,$metadata,$domainRoot,$classes,$columnInfo,$serialization,$namespaces,$constants,$singleOrDump,$baseIriColumn,$modifiedColumn)
};


declare function serialize:find-db($id, $db)
{
let $constants := fn:collection($db)//constants/record
let $baseIriColumn := $constants//baseIriColumn/text()

let $metadata := fn:collection($db)//metadata/record

return
      (: each record in the database must be checked for a match to the requested URI :)
      for $record in $metadata
      where $record/*[local-name()=$baseIriColumn]/text()=$id
      return true()
};

declare function serialize:generate-entire-document($id,$linkedMetadata,$metadata,$domainRoot,$classes,$columnInfo,$serialization,$namespaces,$constants,$singleOrDump,$baseIriColumn,$modifiedColumn)
{
concat(
  (: the namespace abbreviations only needs to be generated once for the entire document :)
  serialize:list-namespaces($namespaces,$serialization),
  string-join(
    if ($singleOrDump = "dump")
    then
      (: this case outputs every record in the database :)
      for $record in $metadata
      let $baseIRI := $domainRoot||$record/*[local-name()=$baseIriColumn]/text()
      let $modified := $record/*[local-name()=$modifiedColumn]/text()
      return serialize:generate-a-record($record,$linkedMetadata,$baseIRI,$domainRoot,$modified,$classes,$columnInfo,$serialization,$namespaces,$constants)
    else
      (: for a single record, each record in the database must be checked for a match to the requested URI :)
      for $record in $metadata
      where $record/*[local-name()=$baseIriColumn]/text()=$id
      let $baseIRI := $domainRoot||$record/*[local-name()=$baseIriColumn]/text()
      let $modified := $record/*[local-name()=$modifiedColumn]/text()
      return serialize:generate-a-record($record,$linkedMetadata,$baseIRI,$domainRoot,$modified,$classes,$columnInfo,$serialization,$namespaces,$constants)
    ),
  serialize:close-container($serialization)
  )
};

declare function serialize:generate-a-record($record,$linkedMetadata,$baseIRI,$domainRoot,$modified,$classes,$columnInfo,$serialization,$namespaces,$constants)
{

          (: Generate unabbreviated URIs and blank node identifiers. This must be done for every record separately since the UUIDs generated for the blank node identifiers must be the same within a record, but differ among records. :)

          let $IRIs := serialize:construct-iri($baseIRI,$classes)
          (: generate a description for each class of resource included in the record :)
          for $modifiedClass in $IRIs
          return serialize:describe-resource($IRIs,$columnInfo,$record,$modifiedClass,$serialization,$namespaces,"")
          ,

          (: now step through each class that's linked to the root class by many-to-one relationships and generate the resource description for each linked resource in that class :)
          for $linkedClass in $linkedMetadata
          return (
            (: determine the constants for the linked class :)
            let $linkColumn := $linkedClass/link_column/text()
            let $linkProperty := $linkedClass/link_property/text()
            let $suffix1 := $linkedClass/suffix1/text()
            let $linkCharacters := $linkedClass/link_characters/text()
            let $suffix2 := $linkedClass/suffix2/text()
            let $linkedClassType := $linkedClass/class/text()

            for $linkedClassRecord in $linkedClass/metadata/record
            where $baseIRI=$domainRoot||$linkedClassRecord/*[local-name()=$linkColumn]/text()

            (: generate an IRI or bnode for the instance of the linked class based on the convention for that class :)
            let $linkedClassIRI :=
                if (fn:substring($suffix1,1,2)="_:")
                then
                    concat("_:",random:uuid() )
                else
                    $baseIRI||"#"||$linkedClassRecord/*[local-name()=$suffix1]/text()||$linkCharacters||$linkedClassRecord/*[local-name()=$suffix2]/text()
            let $linkedIRIs := serialize:construct-iri($linkedClassIRI,$linkedClass/classes/record)
            let $extraTriple := propvalue:iri($linkProperty,$baseIRI,$serialization,$namespaces)
            for $linkedModifiedClass in $linkedIRIs
            return
               serialize:describe-resource($linkedIRIs,$linkedClass/mapping/record,$linkedClassRecord,$linkedModifiedClass,$serialization,$namespaces,$extraTriple)
          )
          ,

          (: The document description is done once for each record. :)
          serialize:describe-document($baseIRI,$modified,$serialization,$namespaces,$constants)

};

(:--------------------------------------------------------------------------------------------------:)

declare function serialize:describe-document($baseIRI,$modified,$serialization,$namespaces,$constants)
{
  let $type := $constants//documentClass/text()
  let $suffix := propvalue:extension($serialization)
  let $iri := concat($baseIRI,$suffix)
  return concat(
    propvalue:subject($iri,$serialization),
    propvalue:plain-literal("dc:format",propvalue:media-type($serialization),$serialization),
    propvalue:plain-literal("dc:creator",$constants//creator/text(),$serialization),

    (: you are welcome to remove the following line if it annoys you :)
    propvalue:plain-literal("rdfs:comment","Generated by Guid-O-Matic 2.0 https://github.com/baskaufs/guid-o-matic",$serialization),

    propvalue:iri("dcterms:references",$baseIRI,$serialization,$namespaces),
    if ($modified)
    then propvalue:datatyped-literal("dcterms:modified",$modified,"xsd:dateTime",$serialization,$namespaces)
    else "",
    propvalue:type($type,$serialization,$namespaces)
  )
};

(:--------------------------------------------------------------------------------------------------:)

declare function serialize:remove-last-comma($temp)
{
  concat(fn:substring($temp,1,fn:string-length($temp)-2),"&#10;")
};

(:--------------------------------------------------------------------------------------------------:)

(: This generates the list of namespace abbreviations used :)
declare function serialize:list-namespaces($namespaces,$serialization)
{
(: Because this is the beginning of the file, it also opens the root container for the serialization (if any) :)
switch ($serialization)
    case "turtle" return concat(
                          string-join(serialize:curie-value-pairs($namespaces,$serialization)),
                          "&#10;"
                        )
    case "xml" return concat(
                          "<rdf:RDF&#10;",
                          string-join(serialize:curie-value-pairs($namespaces,$serialization)),
                          ">&#10;"
                        )
    case "json" return concat(
                          "{&#10;",
                          '"@context": {&#10;',
                          serialize:remove-last-comma(string-join(serialize:curie-value-pairs($namespaces,$serialization))),
                          '},&#10;',
                          '"@graph": [&#10;'
                        )
    default return ""
};

(:--------------------------------------------------------------------------------------------------:)

(: generate sequence of CURIE,value pairs :)
declare function serialize:curie-value-pairs($namespaces,$serialization)
{
  for $namespace in $namespaces
  return switch ($serialization)
        case "turtle" return concat("@prefix ",$namespace/curie/text(),": <",$namespace/value/text(),">.&#10;")
        case "xml" return concat('xmlns:',$namespace/curie/text(),'="',$namespace/value/text(),'"&#10;')
        case "json" return concat('"',$namespace/curie/text(),'": "',$namespace/value/text(),'",&#10;')
        default return ""
};

(:--------------------------------------------------------------------------------------------------:)

(: This function describes a single instance of the type of resource being described by the table :)
declare function serialize:describe-resource($IRIs,$columnInfo,$record,$class,$serialization,$namespaces,$extraTriple)
{
(: Note: the propvalue:subject function sets up any string necessary to open the container, and the propvalue:type function closes the container :)
  let $type := $class/class/text()
  let $id := $class/id/text()
  let $iri := $class/fullId/text()
  return concat(
    propvalue:subject($iri,$serialization),
    string-join(serialize:property-value-pairs($IRIs,$columnInfo,$record,$id,$serialization,$namespaces)),

(: make the backlink only for the instance of the primary class in a table :)
    if ($id="$root")
    then $extraTriple
    else ""
    ,
    propvalue:type($type,$serialization,$namespaces)
  )
  ,
  (: each described resource must be separated by a comma in JSON. The last described resource is the document, which isn't followed by a trailing comma :)
  if ($serialization="json")
  then ",&#10;"
  else ""
};

(:--------------------------------------------------------------------------------------------------:)

(: generate sequence of non-type property/value pair strings :)
declare function serialize:property-value-pairs($IRIs,$columnInfo,$record,$id,$serialization,$namespaces)
{
  (: generates property/value pairs that have fixed values :)
  for $columnType in $columnInfo
  where "$constant" = $columnType/header/text() and $columnType/subject_id/text() = $id
  return switch ($columnType/type/text())
     case "plain" return propvalue:plain-literal($columnType/predicate/text(),$columnType/value/text(),$serialization)
     case "datatype" return propvalue:datatyped-literal($columnType/predicate/text(),$columnType/value/text(),$columnType/attribute/text(),$serialization,$namespaces)
     case "language" return propvalue:language-tagged-literal($columnType/predicate/text(),$columnType/value/text(),$columnType/attribute/text(),$serialization)
     case "iri" return propvalue:iri($columnType/predicate/text(),$columnType/value/text(),$serialization,$namespaces)
     default return ""
,

  (: generates property/value pairs whose values are given in the metadata table :)
  for $column in $record/child::*, $columnType in $columnInfo
  (: The loop only includes columns containing properties associated with the class of the described resource; that column in the record must not be empty :)
  where fn:local-name($column) = $columnType/header/text() and $columnType/subject_id/text() = $id and $column//text() != ""
  return switch ($columnType/type/text())
     case "plain" return propvalue:plain-literal($columnType/predicate/text(),$column//text(),$serialization)
     case "datatype" return propvalue:datatyped-literal($columnType/predicate/text(),$column//text(),$columnType/attribute/text(),$serialization,$namespaces)
     case "language" return propvalue:language-tagged-literal($columnType/predicate/text(),$column//text(),$columnType/attribute/text(),$serialization)
     case "iri" return
       (:: check whether the value column in the mapping table has anything in it :)
       if ($columnType/value/text())
       then
         (: something is there. Construct the IRI by concatenating what's in the value column, the column content, and what's in the attribute column :)
         propvalue:iri($columnType/predicate/text(),$columnType/value/text()||$column//text()||$columnType/attribute/text(),$serialization,$namespaces)
       else
         (: nothing is there.  The column either contains a full IRI or an abbreviated one :)
         propvalue:iri($columnType/predicate/text(),$column//text(),$serialization,$namespaces)
     default return ""
,

  (: generates links to associated resources described in the same document :)
  for $columnType in $columnInfo
  where "$link" = $columnType/header/text() and $columnType/subject_id/text() = $id
  let $suffix := $columnType/value/text()
  return
      for $iri in $IRIs
      where $iri/id/text()=$suffix
      let $object := $iri/fullId/text()
      return propvalue:iri($columnType/predicate/text(),$object,$serialization,$namespaces)
};

(:--------------------------------------------------------------------------------------------------:)

(: this function closes the root container for the serialization (if any) :)
declare function serialize:close-container($serialization)
{
switch ($serialization)
    case "turtle" return ""
    case "xml" return "</rdf:RDF>&#10;"
    case "json" return ']&#10;}'
    default return ""
};

(:--------------------------------------------------------------------------------------------------:)

declare function serialize:construct-iri($baseIRI,$classes)
{
  (: This function basically creates a parallel set of class records that contain the full URIs in addition to the abbreviated ones that are found in classes.csv . In addition, UUID blank node identifiers are generated for nodes that are anonymous.  UUIDs are used instead of sequential numbers since the main function may be hacked to serializa ALL records rather than just one and in that case using UUIDs would ensure that there is no duplication of blank node identifiers among records. :)
  for $class in $classes
  let $suffix := $class/id/text()
  return
     <record>{
     if (fn:substring($suffix,1,2)="_:")
     then (<fullId>{concat("_:",random:uuid() ) }</fullId>, $class/id, $class/class )
     else
       if ($suffix="$root")
       then (<fullId>{$baseIRI}</fullId>, $class/id, $class/class )
       else (<fullId>{concat($baseIRI,$suffix) }</fullId>, $class/id, $class/class )
   }</record>
};

(:--------------------------------------------------------------------------------------------------:)

declare function serialize:html($id,$serialization)
{
 let $value := concat("Placeholder page for local ID=",$id,".")
return
<html>
  <body>
  {$value}
  </body>
</html>
};
