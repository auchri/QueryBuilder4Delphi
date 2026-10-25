unit QueryBuilder4Delphi.Providers.FireDAC.Values;

interface

uses System.Rtti, Data.DB, QueryBuilder4Delphi.Query.Core;

type
  /// <summary>
  /// Converts FireDAC field values and metadata to library types. Driver field types determine
  /// representations; binary values are copied to TBytes, and SQL NULL becomes TValue.Empty.
  /// </summary>
  TFireDACFieldReader = record
    /// <summary>Copies a current field value into a supported TValue representation.</summary>
    /// <param name="F">Non-nil borrowed field; its dataset must be positioned on a row.</param>
    /// <returns>Native scalar/record value or copied TBytes; SQL NULL is TValue.Empty.</returns>
    /// <remarks>
    /// Unsupported fields and Currency-backed BCD fields exceeding supported precision raise EQueryException.
    /// ftFMTBcd avoids Currency storage limitations. Drivers determine the original field type and precision.
    /// </remarks>
    /// <exception cref="EArgumentNilException">F is nil.</exception>
    class function ReadValue(F: TField): TValue; static;
    /// <summary>Classifies a field using its FireDAC-reported data type.</summary>
    /// <param name="Field">Non-nil borrowed field whose driver-reported type is inspected.</param>
    /// <returns>Provider-neutral category, or qtUnknown for an unclassified field type.</returns>
    /// <exception cref="EArgumentNilException">Field is nil.</exception>
    class function ValueType(Field: TField): TQueryValueType; static;
  end;

implementation

uses System.SysUtils, System.Classes, Data.FmtBcd, Data.SqlTimSt;

class function TFireDACFieldReader.ValueType(Field: TField): TQueryValueType;
begin
  if Field = nil then
    raise EArgumentNilException.Create('Field');
  case Field.DataType of
    ftString, ftWideString, ftFixedChar, ftFixedWideChar, ftMemo, ftWideMemo,
      ftFmtMemo, ftOraClob:
      Result := qtString;
    ftSmallint, ftInteger, ftWord, ftShortint, ftByte, ftLongWord:
      Result := qtInteger;
    ftLargeint, ftAutoInc:
      Result := qtInt64;
    ftBoolean:
      Result := qtBoolean;
    ftFloat, ftSingle, ftExtended:
      Result := qtFloat;
    ftCurrency:
      Result := qtCurrency;
    ftBCD, ftFMTBcd:
      Result := qtDecimal;
    ftDate, ftTime, ftDateTime:
      Result := qtDateTime;
    ftTimeStamp:
      Result := qtTimestamp;
    ftTimeStampOffset:
      Result := qtTimestampOffset;
    ftGuid:
      Result := qtGuid;
    ftBytes, ftVarBytes, ftBlob, ftGraphic, ftTypedBinary, ftOraBlob:
      Result := qtBinary;
  else
    Result := qtUnknown;
  end;
end;

class function TFireDACFieldReader.ReadValue(F: TField): TValue;
var
  Stream: TMemoryStream;
  Bytes: TBytes;
begin
  if F = nil then
    raise EArgumentNilException.Create('Field');
  if F.IsNull then
    Exit(TValue.Empty);
  case F.DataType of
    ftString, ftWideString, ftFixedChar, ftFixedWideChar, ftMemo, ftWideMemo,
      ftFmtMemo, ftOraClob:
      Result := TValue.From<string>(F.AsString);
    ftSmallint, ftInteger, ftWord, ftShortint, ftByte:
      Result := TValue.From<Integer>(F.AsInteger);
    ftLongWord:
      Result := TValue.From<Cardinal>(F.AsLongWord);
    ftLargeint, ftAutoInc:
      Result := TValue.From<Int64>(F.AsLargeInt);
    ftBoolean:
      Result := TValue.From<Boolean>(F.AsBoolean);
    ftFloat:
      Result := TValue.From<Double>(F.AsFloat);
    ftSingle:
      Result := TValue.From<Single>(F.AsSingle);
    ftExtended:
      Result := TValue.From<Extended>(F.AsExtended);
    ftCurrency:
      Result := TValue.From<Currency>(F.AsCurrency);
    ftBCD:
      begin
        // A Currency-backed TBCDField may already have lost source precision.
        if (F is TBCDField) and ((F.Size > 4) or (TBCDField(F).Precision > 18))
        then
          raise EQueryException.Create
            ('BCD field exceeds Currency storage; map decimals to ftFMTBcd');
        Result := TValue.From<TBcd>(F.AsBCD);
      end;
    ftFMTBcd:
      Result := TValue.From<TBcd>(F.AsBCD);
    ftDate, ftTime, ftDateTime:
      Result := TValue.From<TDateTime>(F.AsDateTime);
    ftTimeStamp:
      Result := TValue.From<TSQLTimeStamp>(F.AsSQLTimeStamp);
    ftTimeStampOffset:
      Result := TValue.From<TSQLTimeStampOffset>(F.AsSQLTimeStampOffset);
    ftGuid:
      Result := TValue.From<TGUID>(StringToGUID(F.AsString));
    ftBytes, ftVarBytes:
      Result := TValue.From<TBytes>(F.AsBytes);
    ftBlob, ftGraphic, ftTypedBinary, ftOraBlob:
      begin
        Stream := TMemoryStream.Create;
        try
          TBlobField(F).SaveToStream(Stream);
          SetLength(Bytes, Stream.Size);
          if Length(Bytes) > 0 then
            Move(Stream.Memory^, Bytes[0], Length(Bytes));
          Result := TValue.From<TBytes>(Bytes);
        finally
          Stream.Free;
        end;
      end;
    ftVariant:
      Result := TValue.FromVariant(F.Value);
  else
    raise EQueryException.CreateFmt
      ('Unsupported result field type %d for column %s',
      [Ord(F.DataType), F.FieldName]);
  end;
end;

end.
